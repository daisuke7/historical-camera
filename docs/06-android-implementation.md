# 06. Android ネイティブ実装 (Kotlin)

対象: API 26+。使用ライブラリ: CameraX (`camera-core` / `camera-camera2` /
`camera-lifecycle`)、**OpenGL ES 3.0**(EGL14/GLES30)、MediaStore。
ファイルは `android/app/src/main/kotlin/<pkg>/historicalcamera/` 配下(02 §5 参照)。
回転の扱いは 02 §4.1 の回転モデル(センサー向き固定)に厳密に従う。

ES 3.0 を必須とする理由: (a) `highp` 精度保証(03 の hash/noise が mediump では縞状に
破綻する)、(b) PBO・フェンス等の非同期化手段(§3.5)、(c) API 26+ 端末の ES 3.0
サポート率は実質 100% で、ES 2.0 に留まる利益がない。

## 1. 全体構成

```
HistoricalCameraPlugin  … FlutterPlugin + ActivityAware。channel 登録・権限要求・分配
CameraController        … CameraX の Preview / ImageCapture ユースケース管理
FilterRenderer          … GL スレッド + EGL + フラグメントシェーダー(03 §3 の移植)
FilterParams            … data class(@Volatile 参照で GL スレッドへ受け渡し)
MediaWriter             … MediaStore への保存。(P2) MediaRecorder 録画
```

## 2. HistoricalCameraPlugin

- `MainActivity` は `FlutterActivity` のまま、`configureFlutterEngine` で
  `flutterEngine.plugins.add(HistoricalCameraPlugin())` を手動登録。
- `ActivityAware` を実装する(**用途は LifecycleOwner・Activity 参照の取得のみ**)。
  権限要求(`CAMERA` / API 28 以下の `WRITE_EXTERNAL_STORAGE` / (P2) `RECORD_AUDIO`)と
  アプリ設定画面遷移は **Dart 側(permission_handler)の責務**であり、本プラグインには
  要求フローを実装しない。`initialize` 時は `ContextCompat.checkSelfPermission` で
  権限状態のみ確認し、未許可なら `CAMERA_PERMISSION_DENIED` を返す。
- `flutterPluginBinding.textureRegistry` を FilterRenderer に渡す。
- メソッド分配は 02 §3.1 の表どおり。result はメインスレッドで返す。

## 3. 映像パイプライン(このドキュメントの核心)

CameraX の映像を GL でフィルタし、Flutter のテクスチャに描き込む。データは GPU 内で完結する。

```
CameraX Preview ユースケース
  → 出力先: 自前の SurfaceTexture A(GL の OES テクスチャ texIdA に接続)
  → onFrameAvailable → GL スレッドで updateTexImage()
  → フラグメントシェーダー(samplerExternalOES texIdA + FilterParams)で描画
  → 描画先: Flutter TextureRegistry の SurfaceProducer から得た Surface の EGLWindowSurface
  → eglSwapBuffers → Flutter エンジンが自動でフレームを取り込み Texture widget に表示
```

### 3.1 FilterRenderer(GL スレッド)

- `HandlerThread("gl-render")` を立て、その上で EGL 初期化:
  `eglGetDisplay → eglInitialize → eglChooseConfig → eglCreateContext`。
  - `eglCreateContext` の属性: `EGL_CONTEXT_CLIENT_VERSION = 3`(ES 3.0)。
  - `eglChooseConfig` の属性配列: RGBA8888 に加え
    **`EGL_RECORDABLE_ANDROID(0x3142) = 1` を P0 から必ず含める**
    (P2 の MediaRecorder Surface へ描画可能な config は後から差し替えられないため)。
- 出力: **`textureRegistry.createSurfaceProducer()` を使用**
  (`createSurfaceTexture()` は Flutter 3.22+ で非推奨。SurfaceProducer は
  Impeller/Skia 両対応)。**出力寸法は「カメラ解像度をセンサー回転分だけ入れ替えた
  自然向きの寸法」**(例: カメラ 1280x960 → 出力 960x1280。02 §4.1・下記 transform
  行列の実挙動による)。`surfaceProducer.setSize(outW, outH)`(初期化時に確定、
  回転で変えない)→ `surfaceProducer.getSurface()` を `eglCreateWindowSurface` に渡す。
  `surfaceProducer.id()` が Dart へ返す textureId。入力 SurfaceTexture の
  `setDefaultBufferSize` は**カメラ解像度のまま**にする。
  - `SurfaceProducer.Callback` の `onSurfaceAvailable` / `onSurfaceDestroyed` を実装し、
    Surface 差し替え時(background 復帰等)に EGLSurface を作り直すこと。
- 入力: GL スレッドで `glGenTextures`(OES)→ `SurfaceTexture(texIdA)` を生成し
  `setOnFrameAvailableListener(listener, glHandler)`。この SurfaceTexture を
  CameraX へ渡す(§3.2)。
- 描画: 全画面クアッド(三角形2枚)+ フラグメントシェーダー。頂点シェーダーは
  03 §3.1 の固定実装(`#version 300 es` / in・out 構文)。
  - `surfaceTexture.getTransformMatrix()` を `texMatrix` uniform として渡す。
    **この行列には y-flip・クロップに加え、HAL が設定するセンサー回転(背面は通常 90°)が
    常に焼き込まれている**(targetRotation に依らず一定。Pixel 6 実測で確定 —
    implementation-notes #3)。そのためサンプル後のコンテンツは自然向きで正立になる。
  - フロントカメラは水平反転を texMatrix に合成する(プレビューを鏡像にする)。
- フレームドロップ: `onFrameAvailable` が描画中に再入した場合は最新 1 件のみ処理。

### 3.2 CameraController(CameraX)

1. `ProcessCameraProvider.getInstance(context)` を取得。
2. `Preview.Builder()` に `ResolutionSelector.Builder().setResolutionStrategy(
   ResolutionStrategy(Size(1280, 720), FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER))` を設定
   (`setTargetResolution` は非推奨)。
   `setSurfaceProvider { request -> request.provideSurface(Surface(surfaceTextureA), executor) {} }`。
   **`request.resolution` を正**とし、`surfaceTextureA.setDefaultBufferSize` と Dart へ返す
   previewWidth/Height にこれを使う(リクエストと異なる値が来ることがある。
   アスペクト比も端末依存 — 02 §3.1。Pixel 6 実測では 1280×720 要求に対し
   1280×960(4:3)が選ばれた)。
3. `ImageCapture.Builder().setCaptureMode(CAPTURE_MODE_MAXIMIZE_QUALITY).build()`(静止画用)。
4. `cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageCapture)`。
   LifecycleOwner は Activity(`ActivityAware` で取得)を使う。
5. `pausePreview`/`resumePreview` は `cameraProvider.unbind(preview)` / 再 bind で実現。

### 3.3 回転対応(02 §4.1 のモデル。P0 実装で実挙動に合わせて改訂)

- コンテンツは transform 行列の実挙動(§3.1)により**常に自然向きで正立**。
  よって quarterTurns は**ディスプレイ回転の打ち消しのみ**:
  `quarterTurns = (-displayRotation/90) mod 4`(縦=0、横=∓1)。
  `DisplayManager.DisplayListener` で UI 回転を監視して
  (a) EventChannel `orientationChanged` で Dart へ通知、
  (b) シェーダーの `orientation` uniform に設定する。
- **`preview.targetRotation` はセンサー向きに固定し、以後変更しない**
  (`quartersToRotation(sensorRotationDegrees / 90)`)。targetRotation を表示回転に
  追従させると CameraX が transform を変化させ、固定寸法バッファでアスペクトが崩れる。
  `TransformationInfo` は診断用途のみに使う(固定後は常に 0 のはず)。
- 静止画: `imageCapture.targetRotation` は物理向きへ追従させる
  (`OrientationEventListener`。CameraX が JPEG の EXIF を正しく付ける)。
- **デバイス依存の自己診断(P1)**: 上記は「HAL が buffer transform にセンサー回転を
  焼き込む」ことに依存する。設定しない機種の存在に備え、最初の `updateTexImage()` 直後に
  transform 行列の回転成分を検査する自己診断を実装する(現行モデルの維持が前提。
  **自動切替は行わない**):
  - `detectBakedQuarterTurns(matrix): Int?` — 4×4 行列の 2×2 回転部から 90° 単位の回転量を
    判定する**純粋関数**(y-flip・クロップ由来のスケール/平行移動は正規化して無視。
    90° 格子に乗らない行列は null)。合成行列(単位行列・y-flip のみ・90°回転+flip・
    クロップ付き)でのユニットテストを必須とする。
  - 判定結果がカメラの `sensorRotationDegrees` と矛盾する場合、`Log.w` で行列全体を出力し、
    EventChannel `error`(code: `ROTATION_MODEL_MISMATCH`)を**一度だけ**送出する。
    このコードは診断専用(非致命)であり、Dart は UI 状態を変えない(02 §3.2)。
    プレビューは現行モデルのまま描画を継続する。
  - 新しいテスト機での手動回転検証(08 T11 の 4 方向×プレビュー/保存写真)は引き続き実施し、
    この診断は想定外機種の**検知を自動化**する位置づけとする。

### 3.4 静止画キャプチャ(`capturePhoto`)

**プレビューの GL スレッド(gl-render)では行わない。** 4032×3024 級の処理
(アップロード+描画+読み戻しで数百 ms)がプレビューを 10 フレーム以上凍結させるため、
**プレビューと EGL コンテキストを共有する第 2 の GL スレッド(`HandlerThread("gl-still")`)**
を initialize 時に作っておき、そこで実行する(シェーダープログラムは共有コンテキストで再利用可)。

1. `imageCapture.takePicture(executor, OnImageCapturedCallback)` で `ImageProxy`(JPEG)取得。
2. JPEG → `Bitmap` にデコード(EXIF 回転を適用して**正立ビットマップ**にする。
   フロントカメラはプレビューと同じ鏡像になるよう水平反転 — 02 §4.1)。
3. gl-still スレッドでフル解像度フィルタ適用:
   - Bitmap を通常の `GL_TEXTURE_2D` にアップロードし、**直後に `bitmap.recycle()`**
   - フル解像度の FBO(texture attachment)に 03 のシェーダーで描画
     (orientation uniform = 0、texMatrix = 単位行列、grainSize は 03 §4 のスケール)。
     `GL_MAX_TEXTURE_SIZE`(多くの端末で 4096)を超える場合は長辺 4096 に縮小してから処理
   - `glReadPixels` → Bitmap(**同時生存する 48MB 級バッファは最大 2 面に抑える**。
     `OutOfMemoryError` 時は長辺 3072 で 1 回だけ再試行し、失敗なら `CAPTURE_FAILED`)
4. JPEG(品質 90)を `context.cacheDir` 配下の一時ファイルに書き、その File を
   `MediaWriter.save()`(MediaStore へコピー)に渡す。**result で返す `path` は
   この一時ファイルの絶対パス**(iOS の NSTemporaryDirectory 方式と同じ意味。
   MediaStore の content URI は返さない)。JPEG エンコードは書き込みスレッドで行う。
5. シェーダーは入力サンプラが `samplerExternalOES`(プレビュー)と `sampler2D`(静止画)の
   2 変種が必要。**ソースは 1 本にし、先頭に `#define` を差し込んで 2 回コンパイルする**
   (アルゴリズムの二重管理禁止)。

### 3.5 (P2 に向けた注記)

録画時は同一フレームをエンコーダサーフェスにも描く必要がある(07 §3)。
描画関数は最初から `draw(target: EGLSurface, texMatrix, orientation)` の形にし、
描画先を引数化しておくこと(プレビュー専用にハードコードしない)。

## 4. FilterParams の受け渡し

- MethodChannel(メインスレッド)で Map → `FilterParams` data class に変換
  (値は `(v as Number).toDouble()` で読む — 02 §2 の型規約)し、
  `@Volatile var latestParams` に代入。**初期値は中立値**(02 §2。全ゼロ初期化禁止)。
- GL スレッドは描画ごとに最新値を読み、uniform として渡す。uniform 一式:
  **FilterParams の 20 値(`glUniform1f` ×20、02 §2 の宣言順)+ `time` +
  `resolution`(vec2。§3.2 の request.resolution 基準)+ `orientation`(float)+
  `texMatrix`(mat4)**(03 §3.1)。
- `time` は `(SystemClock.elapsedRealtime() - start) / 1000.0 % 3600.0`(03 §3.4)。

## 5. MediaWriter

- API 29+: `MediaStore.Images` に `RELATIVE_PATH = "Pictures/HistoricalCamera"` で insert →
  OutputStream に JPEG を書く(`IS_PENDING` フラグ運用)。
- API 26–28: `WRITE_EXTERNAL_STORAGE` 権限(§2)+ 公開 Pictures ディレクトリ書き込み +
  `MediaScannerConnection.scanFile`。
- (P2) 録画は 07 参照。`MediaRecorder` はこのクラスに実装する。

## 6. ライフサイクル・エラー・サーマル・その他

- `dispose` の解放順(**厳守**。implementation-notes #3 の FlutterJNI クラッシュ対策):
  ① 描画停止フラグを**同期**セット(以後 `eglSwapBuffers` を発行しない)→
  ② `surfaceProducer.release()`(エンジン側で遅延配送フレームをガード)→
  ③ カメラ unbindAll・各リスナー解除 → ④ GL/EGL 資源解放(gl-still 含む)→ スレッド終了。
  エンジン切断後にキュー済みフレームが配送されると
  「FlutterJNI is not attached」で落ちるため、①②を必ず先頭で行い、
  `onDetachedFromEngine` でも dispose を呼ぶこと。
- エラー(カメラ切断等)は CameraX の `CameraState` を observe し EventChannel `error` へ。
- **サーマル**: `PowerManager.addThermalStatusListener` を購読し EventChannel `thermal` へ変換。
  `THERMAL_STATUS_SEVERE` 以上で CameraX の `setTargetFrameRate(Range(24, 24))` 相当の
  再バインドを行い 24fps へ低減(02 §6.1)。
- 画面スリープ抑止は Dart 側(wakelock_plus)の責務であり、本プラグインでは行わない。
- `AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA"/>`、
  `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
  android:maxSdkVersion="28"/>`、
  `<uses-feature android:name="android.hardware.camera" android:required="true"/>`。

## 7. 実装順

1. Plugin 骨格 + 権限 + GL パススルー(カメラ映像を無加工で Texture 表示)
2. 03 の色調系 → ノイズ系 → engraving/inkPainting(iOS と同順)
3. capturePhoto(gl-still スレッド+フル解像度適用+ MediaStore 保存)
4. pause/resume・回転通知・サーマル・エラーイベント

## 8. 既知の落とし穴(実装時に必ず確認)

- `updateTexImage()` は SurfaceTexture を生成した GL コンテキストのスレッドでしか呼べない。
- `provideSurface` の resolution はリクエストと異なる値が来ることがある。必ず
  `request.resolution` を正とし、Dart へ返す previewWidth/Height にもこれを使う。
- フラグメントシェーダー先頭の `precision highp float;` を忘れない(03 §3.4)。
- `eglSwapBuffers`(プレビュー側)は Flutter エンジンの消費遅延でブロックし得る。
  (P2)録画中はエンコーダサーフェスへの描画・swap をプレビュー側 swap より先に行い、
  録画フレームの欠落を防ぐこと。
- エミュレータは OES テクスチャ+CameraX の組合せが不安定。実機で検証する。
- SurfaceProducer(§3.1)でもプレビューが映らない場合の最終手段としてのみ、
  `AndroidManifest.xml` のメタデータで Impeller を無効化して切り分ける
  (恒久対応にはしない。Flutter 側の既知問題を確認して issue 対応する)。
