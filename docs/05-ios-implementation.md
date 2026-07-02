# 05. iOS ネイティブ実装 (Swift)

対象: iOS 15+。使用フレームワーク: AVFoundation, Metal, CoreVideo, Photos。
外部ライブラリは使わない。ファイルは `ios/Runner/HistoricalCamera/` 配下(02 §5 参照)。
回転の扱いは 02 §4.1 の回転モデル(センサー向き固定)に厳密に従う。

## 1. 全体構成

```
HistoricalCameraPlugin  … FlutterPlugin。MethodChannel/EventChannel の登録と分配のみ
CameraController        … AVCaptureSession 管理・フレーム供給・静止画キャプチャ
FilterRenderer          … Metal compute kernel(03 §3 の移植)。FlutterTexture 実装
FilterParams            … Swift struct(Metal の uniform とメモリレイアウト一致)
MediaWriter             … PHPhotoLibrary への保存。(P2) AVAssetWriter 録画
```

## 2. HistoricalCameraPlugin

- `AppDelegate.application(_:didFinishLaunching...)` で
  `HistoricalCameraPlugin.register(with: registrar(forPlugin:))` を手動登録
  (pub パッケージ化はしない。Runner 内に直接置く)。
- `FlutterMethodChannel(name: "historical_camera/method")` と
  `FlutterEventChannel(name: "historical_camera/event")` を生成。
- `registrar.textures()`(`FlutterTextureRegistry`)を FilterRenderer に渡す。
- メソッド分配は 02 §3.1 の表どおり。**結果の result() 呼び出しは必ずメインスレッドで行う。**
- 権限要求・アプリ設定画面遷移は Dart 側(permission_handler)の責務であり、
  本プラグインには実装しない。

## 3. CameraController

### 3.1 セッション構築(`initialize`)

1. `AVCaptureDevice.authorizationStatus(for: .video)` を確認し、`.authorized` 以外なら
   `CAMERA_PERMISSION_DENIED` を throw(権限要求は Dart 側が initialize 前に
   permission_handler で実施済み — 02 §3.1)。
2. `AVCaptureSession` を生成し `sessionPreset = .hd1280x720`(`resolutionPreset` 引数で
   `.hd1920x1080` に切替可)。
3. 入力: `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back/.front)`。
4. 出力1: `AVCaptureVideoDataOutput`
   - `videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]`
     (**BGRA を指定**。YUV→RGB 変換をシェーダーから排除し実装を単純化する)
   - `alwaysDiscardsLateVideoFrames = true`
   - delegate queue: 専用 serial queue `camera.capture`
   - connection の向きは**固定**(センサー向きのまま。`videoOrientation` の毎回更新は
     行わない — 02 §4.1)。フロントカメラのみ、`connection.automaticallyAdjustsVideoMirroring
     = false` を設定した**うえで** `isVideoMirrored = true`(先に無効化しないと例外)。
5. 出力2: `AVCapturePhotoOutput`(静止画用)。**フル解像度写真のための設定が必須**
   (プリセットが .hd1280x720 のままでは写真も 720p 相当になる):
   - iOS 16+: `photoOutput.maxPhotoDimensions = activeFormat.supportedMaxPhotoDimensions.last!`
   - iOS 15: `photoOutput.isHighResolutionCaptureEnabled = true`(撮影時の settings にも
     `isHighResolutionPhotoEnabled = true` を指定)
   - 実際に得られる解像度は端末・フォーマット依存。T7 の検証で実解像度を確認し、
     12MP に満たない端末は「その端末の最大」を仕様とする(受け入れ基準もそれに従う)。
6. `session.startRunning()`(専用キューで。メインスレッド禁止)。

### 3.2 フレーム供給

`captureOutput(_:didOutput:from:)` で `CVPixelBuffer` を取り出し、
`FilterRenderer.enqueue(pixelBuffer:)` を呼ぶだけ。ここでは処理しない。

### 3.3 回転対応(02 §4.1 のモデル)

- **プレビューバッファは回転しない。** ネイティブが行うのは向きの「通知」と「uniform 供給」のみ。
- `UIDevice.current.beginGeneratingDeviceOrientationNotifications()` を呼んだうえで
  `UIDevice.orientationDidChangeNotification` を購読(呼ばないと通知が発火しない)。
- 向き変化時: quarterTurns(テクスチャを表示上正立させる時計回り 90°×N)を計算し、
  (a) EventChannel で `orientationChanged {quarterTurns}` を送出、
  (b) FilterRenderer の `orientation` uniform を更新、
  (c) 次回撮影用に現在向きを保持する。
- `videoOrientation` API(iOS 17 で deprecated)には依存しない。

### 3.4 静止画キャプチャ(`capturePhoto`)

1. `AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey: BGRA])` で
   **無圧縮 BGRA の photo を要求**(事前に `photoOutput.availablePhotoPixelFormatTypes` に
   BGRA が含まれることを確認。なければ `CAPTURE_FAILED`)。iOS 15 では
   `isHighResolutionPhotoEnabled = true` も指定(§3.1)。
2. delegate で `photo.pixelBuffer` を取得。**このバッファはセンサー向きのまま届く**
   (photo connection の向き設定は EXIF メタデータにしか影響しない)。
   `photo.metadata` の Orientation と §3.3 で保持した向きから回転量を決め、
   **フィルタ適用前に Metal でピクセルを正立向きへ回転する**(縦傷など向き依存
   エフェクトを表示上の縦にそろえるため)。フロントカメラは**プレビューと同じ鏡像**になる
   よう水平反転を合成する(02 §4.1)。
3. `FilterRenderer.renderStill(pixelBuffer, params)` でフィルタ適用
   (03 §4: grainSize を解像度比でスケール、orientation uniform = 0、
   time は撮影時点のプレビュー time)。**renderStill は専用の `MTLCommandQueue` を使う**
   (プレビューのキューを塞がない。撮影瞬間のプレビュー落ちは 2 フレーム以内を許容値とする)。
4. 出力 `CVPixelBuffer` → `CIImage` → `CIContext.jpegRepresentation(quality: 0.9)`。
   JPEG エンコードと EXIF 付与(Orientation は回転済みのため `.up`、撮影日時)は
   書き込みスレッドで行う。
5. `MediaWriter.saveToPhotoLibrary(jpegData)` → `NSTemporaryDirectory()` に書いた
   一時ファイルの絶対パスを result で返す(02 §3.1 の path の意味)。

## 4. FilterRenderer(Metal)

### 4.1 パイプライン

```
CVPixelBuffer(カメラ, BGRA)
  → CVMetalTextureCache で MTLTexture(read)化(ゼロコピー)
  → compute kernel "eraFilter"(03 §3 のアルゴリズム)
  → 出力: CVPixelBufferPool から取得した BGRA バッファを MTLTexture(write)化
  → commandBuffer.commit()、completion で latestOutputBuffer を差し替え
  → textureRegistry.textureFrameAvailable(textureId)
```

- 初期化: `MTLCreateSystemDefaultDevice()`, `makeCommandQueue()`,
  `CVMetalTextureCacheCreate`, 出力用 `CVPixelBufferPool`。プール生成属性:
  `kCVPixelBufferMetalCompatibilityKey: true`、
  **`kCVPixelBufferIOSurfacePropertiesKey: [:]`(Flutter 表示に IOSurface backing が必須)**、
  幅高はプレビューサイズ(横長固定。回転で変えない — 02 §4.1)。
- **プールサイズ: P0 は 4 枚、録画中(P2)は 8 枚。** 同時に「レンダリング中 1 +
  latestOutputBuffer 1 + Flutter が copyPixelBuffer で retain 中 1〜2(+ 録画エンコーダ
  retain 中)」が生きるため。プール枯渇時は**そのフレームの描画をスキップして直前の出力を
  維持する**(クラッシュ・ブロック禁止)。
- **FlutterTexture プロトコルの実装**: `copyPixelBuffer()` は
  `latestOutputBuffer` を `Unmanaged.passRetained` で返す。アクセスは os_unfair_lock で保護。
- レンダーとフレーム到着の背圧: 前フレームの GPU 実行が未完了なら新フレームを破棄
  (`isRendering` フラグ)。カメラ 30fps に対し十分間に合うが安全弁として置く。

### 4.2 カーネル(`Shaders.metal`)

- 03 §3 の GLSL 疑似コードを MSL に移植。`kernel void eraFilter(texture2d<float, access::sample> src, texture2d<float, access::write> dst, constant Uniforms& u, uint2 gid)`。
- **ディスパッチは `dispatchThreadgroups` + カーネル先頭の境界ガード
  `if (gid.x >= u.width || gid.y >= u.height) return;` で書くこと**
  (`dispatchThreads` は A11 未満の端末でクラッシュするため使用禁止)。
- `Uniforms` struct のフィールド順は **02 §2 の FilterParams 宣言順(monochrome →…→
  paperTexture の 20 個)+ time + width + height + orientation の計 24 個の Float** とし、
  Swift・MSL 両方でこの順を厳守する(全て Float の平坦な struct にして alignment 問題を
  避ける。vec 型は使わない)。texMatrix は iOS では不要(単位行列相当として省略してよいが、
  省略する場合は suv = uv とする)。
- サンプラ: `filter::linear, address::clamp_to_edge`。
- **FilterParams の初期値は中立値**(02 §2。全ゼロ初期化禁止)。
- パススルー検証: 全パラメータ中立で入出力一致(ユニットテスト対象)。

### 4.3 FilterParams の受け渡し

- MethodChannel(メインスレッド)で Map → `FilterParams` に変換し、
  `renderer.params = newParams`(struct 代入、プロパティを lock で保護)。
- kernel 実行時に毎回 `setBytes` で渡す(バッファ常駐管理は不要な小ささ)。
- `time` は `fmod(起動からの経過秒, 3600.0)`(03 §3.4)。

## 5. MediaWriter

- `PHPhotoLibrary.requestAuthorization(for: .addOnly)` → 
  `PHAssetCreationRequest.forAsset().addResource(with: .photo, data: jpegData)`。
- Info.plist: `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`,
  (P2) `NSMicrophoneUsageDescription`。
- (P2) 録画: 07 参照。`AVAssetWriter` はこのクラスに実装する。

## 6. ライフサイクル・エラー・サーマル

- `pausePreview` → `session.stopRunning()` / `resumePreview` → `startRunning()`(専用キュー)。
- `AVCaptureSession.wasInterruptedNotification` / `runtimeErrorNotification` を購読し、
  EventChannel `error` イベントに変換。
- **サーマル**: `ProcessInfo.thermalStateDidChangeNotification` を購読し、EventChannel
  `thermal` に変換。`.serious` 以上で `activeVideoMinFrameDuration` を 1/24 秒に設定して
  24fps へ低減(1080p 動作中なら 720p 相当へ降格。02 §6.1)。
- `dispose`: session 停止 → textureRegistry.unregisterTexture → Metal 資源解放。
- 画面スリープ抑止は Dart 側(wakelock_plus)の責務であり、本プラグインでは行わない。

## 7. 実装順(このファイル内のマイルストーン)

1. Plugin 骨格 + `initialize` でカメラ映像を**無加工のまま** Texture に出す(パススルー kernel)
2. 03 の色調系(monochrome/orthochromatic/sepia/saturation/contrast/brightness/warmth/fade/vignette)
3. ノイズ系(grain/scratches/dust/jitter/halation/blur/paperTexture)
4. engraving(hatchScale 含む)/ inkPainting
5. capturePhoto(正立回転+フル解像度適用+保存)
6. pause/resume・回転通知・サーマル・エラーイベント
