# 06. Android ネイティブ実装 (Kotlin)

対象: API 26+。使用ライブラリ: CameraX (`camera-core` / `camera-camera2` /
`camera-lifecycle`)、OpenGL ES 2.0(EGL14/GLES20)、MediaStore。
ファイルは `android/app/src/main/kotlin/<pkg>/historicalcamera/` 配下(02 §5 参照)。

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
- `ActivityAware` を実装し、権限要求(`CAMERA`; P2 で `RECORD_AUDIO`)を
  `ActivityCompat.requestPermissions` + `RequestPermissionsResultListener` で処理。
- `flutterPluginBinding.textureRegistry` を FilterRenderer に渡す。
- メソッド分配は 02 §3.1 の表どおり。result はメインスレッドで返す。

## 3. 映像パイプライン(このドキュメントの核心)

CameraX の映像を GL でフィルタし、Flutter のテクスチャに描き込む。データは GPU 内で完結する。

```
CameraX Preview ユースケース
  → 出力先: 自前の SurfaceTexture A(GL の OES テクスチャ texIdA に接続)
  → onFrameAvailable → GL スレッドで updateTexImage()
  → フラグメントシェーダー(samplerExternalOES texIdA + FilterParams)で描画
  → 描画先: Flutter TextureRegistry の SurfaceTexture B から作った EGLWindowSurface
  → eglSwapBuffers → Flutter エンジンが自動でフレームを取り込み Texture widget に表示
```

### 3.1 FilterRenderer(GL スレッド)

- `HandlerThread("gl-render")` を立て、その上で EGL 初期化:
  `eglGetDisplay → eglInitialize → eglChooseConfig(RGBA8888, ES2) → eglCreateContext`。
- 出力: `textureRegistry.createSurfaceTexture()` → `surfaceTextureEntry.surfaceTexture()` に
  `setDefaultBufferSize(previewWidth, previewHeight)` → `Surface` 化 →
  `eglCreateWindowSurface`。`entry.id()` が Dart へ返す textureId。
- 入力: GL スレッドで `glGenTextures`(OES)→ `SurfaceTexture(texIdA)` を生成し
  `setOnFrameAvailableListener(listener, glHandler)`。この SurfaceTexture を
  CameraX へ渡す(§3.2)。
- 描画: 全画面クアッド(三角形2枚)+ フラグメントシェーダー。
  `surfaceTexture.getTransformMatrix()` を UV 変換行列 uniform として必ず適用する
  (これが回転・クロップ補正を担う)。
- フレームドロップ: `onFrameAvailable` が描画中に再入した場合は最新 1 件のみ処理。

### 3.2 CameraController(CameraX)

1. `ProcessCameraProvider.getInstance(context)` を取得。
2. `Preview.Builder().setTargetResolution(Size(1280, 720)).build()` に対し
   `setSurfaceProvider { request -> request.provideSurface(Surface(surfaceTextureA), executor) {} }`。
   `request.resolution` に合わせて `surfaceTextureA.setDefaultBufferSize` を設定する。
3. `ImageCapture.Builder().setCaptureMode(CAPTURE_MODE_MAXIMIZE_QUALITY).build()`(静止画用)。
4. `cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageCapture)`。
   LifecycleOwner は Activity(`ActivityAware` で取得)を使う。
5. `pausePreview`/`resumePreview` は `cameraProvider.unbind(preview)` / 再 bind で実現。

### 3.3 回転対応

- プレビュー: SurfaceTexture の transform matrix + `preview.targetRotation = display.rotation`
  で正立させる。`OrientationEventListener` で回転変化時に targetRotation を更新。
- 静止画: `imageCapture.targetRotation` を撮影直前に更新。CameraX が EXIF を正しく付ける。

### 3.4 静止画キャプチャ(`capturePhoto`)

1. `imageCapture.takePicture(executor, OnImageCapturedCallback)` で `ImageProxy`(JPEG)取得。
2. JPEG → `Bitmap` にデコード(EXIF 回転を適用して正立ビットマップにする)。
3. GL スレッドでフル解像度フィルタ適用:
   - Bitmap を通常の `GL_TEXTURE_2D` にアップロード
   - フル解像度の FBO(renderbuffer ではなく texture attachment)に 03 のシェーダーで描画。
     **`GL_MAX_TEXTURE_SIZE`(多くの端末で 4096)を超える場合は長辺 4096 に縮小してから処理**
   - `glReadPixels` → Bitmap
   - grainSize は 03 §4 のとおり解像度比でスケール
4. JPEG(品質 90)にエンコードし `MediaWriter.save()` → path を result で返す。
5. シェーダーは入力サンプラが `samplerExternalOES`(プレビュー)と `sampler2D`(静止画)の
   2 変種が必要。**ソースは 1 本にし、先頭に `#define` を差し込んで 2 回コンパイルする**
   (アルゴリズムの二重管理禁止)。

## 4. FilterParams の受け渡し

- MethodChannel(メインスレッド)で Map → `FilterParams` data class に変換し、
  `@Volatile var latestParams` に代入。GL スレッドは描画ごとに読み、`glUniform1f` ×18 で渡す。
- `time` uniform はレンダラー起動からの経過秒(`SystemClock.elapsedRealtime()` 基準)。

## 5. MediaWriter

- API 29+: `MediaStore.Images` に `RELATIVE_PATH = "Pictures/HistoricalCamera"` で insert →
  OutputStream に JPEG を書く(`IS_PENDING` フラグ運用)。
- API 26–28: `WRITE_EXTERNAL_STORAGE` 権限 + 公開 Pictures ディレクトリ書き込み +
  `MediaScannerConnection.scanFile`。
- (P2) 録画は 07 参照。`MediaRecorder` はこのクラスに実装する。

## 6. ライフサイクル・エラー・その他

- `dispose`: unbindAll → GL スレッドで EGL 資源解放 → HandlerThread 終了 →
  `surfaceTextureEntry.release()`。**解放順を厳守**(EGL 解放前に SurfaceTexture を
  release すると `eglSwapBuffers` がクラッシュする)。
- エラー(カメラ切断等)は CameraX の `CameraState` を observe し EventChannel `error` へ。
- 画面スリープ抑止: preview 中 `activity.window.addFlags(FLAG_KEEP_SCREEN_ON)`。
- `AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA"/>`、
  `<uses-feature android:name="android.hardware.camera" android:required="true"/>`。

## 7. 実装順

1. Plugin 骨格 + 権限 + GL パススルー(カメラ映像を無加工で Texture 表示)
2. 03 の色調系 → ノイズ系 → engraving/inkPainting(iOS と同順)
3. capturePhoto(フル解像度適用+ MediaStore 保存)
4. pause/resume・回転・エラーイベント

## 8. 既知の落とし穴(実装時に必ず確認)

- `updateTexImage()` は SurfaceTexture を生成した GL コンテキストのスレッドでしか呼べない。
- `provideSurface` の resolution はリクエストと異なる値が来ることがある。必ず
  `request.resolution` を正とし、Dart へ返す previewWidth/Height にもこれを使う。
- エミュレータは OES テクスチャ+CameraX の組合せが不安定。実機で検証する。
- Impeller(Android)有効時の外部テクスチャ表示は Flutter 安定版で動作確認すること。
  問題があれば `AndroidManifest.xml` のメタデータで Impeller を無効化して回避できる。
