# 05. iOS ネイティブ実装 (Swift)

対象: iOS 15+。使用フレームワーク: AVFoundation, Metal, CoreVideo, Photos。
外部ライブラリは使わない。ファイルは `ios/Runner/HistoricalCamera/` 配下(02 §5 参照)。

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

## 3. CameraController

### 3.1 セッション構築(`initialize`)

1. `AVCaptureDevice.authorizationStatus(for: .video)` を確認。`.notDetermined` なら
   `requestAccess` で要求。拒否なら `CAMERA_PERMISSION_DENIED` を throw。
2. `AVCaptureSession` を生成し `sessionPreset = .hd1280x720`(`resolutionPreset` 引数で
   `.hd1920x1080` に切替可)。
3. 入力: `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back/.front)`。
4. 出力1: `AVCaptureVideoDataOutput`
   - `videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]`
     (**BGRA を指定**。YUV→RGB 変換をシェーダーから排除し実装を単純化する)
   - `alwaysDiscardsLateVideoFrames = true`
   - delegate queue: 専用 serial queue `camera.capture`
5. 出力2: `AVCapturePhotoOutput`(静止画用)。
6. connection 設定: `videoOrientation` はデバイス向きに追従(§3.3)、front カメラは
   `isVideoMirrored = true`。
7. `session.startRunning()`(専用キューで。メインスレッド禁止)。

### 3.2 フレーム供給

`captureOutput(_:didOutput:from:)` で `CVPixelBuffer` を取り出し、
`FilterRenderer.enqueue(pixelBuffer:)` を呼ぶだけ。ここでは処理しない。

### 3.3 回転対応

- `UIDevice.orientationDidChangeNotification` を購読し、video connection の
  `videoOrientation` を更新する。これによりプレビューテクスチャは常に「表示上の上が上」の
  ピクセルになり、**Flutter 側は回転を意識しない**(02 の責務どおり)。
- 静止画は `photoOutput.connection(with: .video)?.videoOrientation` を撮影直前に設定。

### 3.4 静止画キャプチャ(`capturePhoto`)

1. `AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey: BGRA])` で
   **無圧縮 BGRA の photo を要求**(フィルタ適用前の JPEG デコードを避ける)。
2. delegate で `photo.pixelBuffer` を取得 → `FilterRenderer.renderStill(pixelBuffer, params)`
   でフィルタ適用(03 §4 の grainSize スケーリングを適用)。
3. 出力 `CVPixelBuffer` → `CIImage` → `CIContext.jpegRepresentation(quality: 0.9)`。
4. EXIF: `kCGImagePropertyOrientation` は connection で正立済みのため `.up` を指定。
   撮影日時はメタデータ辞書で付与。
5. `MediaWriter.saveToPhotoLibrary(jpegData)` → 完了後、一時ディレクトリ
   (`NSTemporaryDirectory()`)に書いたファイルの path を result で返す。

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
  `CVMetalTextureCacheCreate`, 出力用 `CVPixelBufferPool`
  (`kCVPixelBufferMetalCompatibilityKey: true`, 幅高はプレビューサイズ)。
- **FlutterTexture プロトコルの実装**: `copyPixelBuffer()` は
  `latestOutputBuffer` を `Unmanaged.passRetained` で返す。アクセスは os_unfair_lock で保護。
- レンダーとフレーム到着の背圧: 前フレームの GPU 実行が未完了なら新フレームを破棄
  (`isRendering` フラグ)。カメラ 30fps に対し十分間に合うが安全弁として置く。

### 4.2 カーネル(`Shaders.metal`)

- 03 §3 の GLSL 擬似コードを MSL に移植。`kernel void eraFilter(texture2d<float, access::sample> src, texture2d<float, access::write> dst, constant Uniforms& u, uint2 gid)`。
- `Uniforms` struct: FilterParams の 18 float + `time` + `width/height`。
  **Swift 側 struct と `MemoryLayout` が一致するようフィールド順を固定**(全て Float、
  alignment 問題を避けるため vec 型は使わない)。
- サンプラ: `filter::linear, address::clamp_to_edge`。
- パススルー検証: 全パラメータ中立で入出力一致(ユニットテスト対象)。

### 4.3 FilterParams の受け渡し

- MethodChannel(メインスレッド)で Map → `FilterParams` に変換し、
  `renderer.params = newParams`(struct 代入、プロパティを lock で保護)。
- kernel 実行時に毎回 `setBytes` で渡す(バッファ常駐管理は不要な小ささ)。

## 5. MediaWriter

- `PHPhotoLibrary.requestAuthorization(for: .addOnly)` → 
  `PHAssetCreationRequest.forAsset().addResource(with: .photo, data: jpegData)`。
- Info.plist: `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`,
  (P2) `NSMicrophoneUsageDescription`。
- (P2) 録画: 07 参照。`AVAssetWriter` はこのクラスに実装する。

## 6. ライフサイクル・エラー

- `pausePreview` → `session.stopRunning()` / `resumePreview` → `startRunning()`(専用キュー)。
- `AVCaptureSession.wasInterruptedNotification` / `runtimeErrorNotification` を購読し、
  EventChannel `error` イベントに変換。
- `dispose`: session 停止 → textureRegistry.unregisterTexture → Metal 資源解放。
- 画面スリープ抑止: preview 中 `UIApplication.shared.isIdleTimerDisabled = true`。

## 7. 実装順(このファイル内のマイルストーン)

1. Plugin 骨格 + `initialize` でカメラ映像を**無加工のまま** Texture に出す(パススルー kernel)
2. 03 の色調系(monochrome/sepia/saturation/contrast/brightness/warmth/fade/vignette)を実装
3. ノイズ系(grain/scratches/dust/jitter/halation/blur/paperTexture)
4. engraving / inkPainting
5. capturePhoto(フル解像度適用+保存)
6. pause/resume・回転・エラーイベント
