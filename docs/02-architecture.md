# 02. アーキテクチャと Platform Channel API 仕様

このドキュメントが **インターフェース定義の単一情報源**。channel 名・メソッド名・
パラメータ名・型は本書の記載を正とし、実装時に変更しないこと。

## 1. レイヤー構成

```
┌─────────────────────────────────────────────────────┐
│ Flutter / Dart                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ UI 層         │ │ 状態管理      │ │ ドメイン層     │ │
│  │ CameraScreen │ │ CameraState  │ │ EraFilter    │ │
│  │ EraSlider    │ │ (ChangeNoti- │ │ (年代→Filter │ │
│  │ ShutterButton│ │  fier)       │ │  Params 変換) │ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ │
│         └────────────────┴────────────────┘          │
│                          │                           │
│               NativeCameraApi (Dart ラッパー)         │
└──────────────────────────┼───────────────────────────┘
              MethodChannel / EventChannel / Texture
┌──────────────────────────┼───────────────────────────┐
│ ネイティブ層 (iOS: Swift / Android: Kotlin)            │
│  ┌────────────┐ ┌───────────────┐ ┌───────────────┐  │
│  │ Camera     │ │ FilterRenderer │ │ MediaWriter   │  │
│  │ Controller │→│ (GPU シェーダー) │→│ 写真保存/録画  │  │
│  └────────────┘ └───────┬───────┘ └───────────────┘  │
│                         ↓                             │
│              Flutter TextureRegistry(外部テクスチャ)    │
└───────────────────────────────────────────────────────┘
```

### モジュール責務

| モジュール | 言語 | 責務 |
|-----------|------|------|
| `CameraScreen` | Dart | 全画面 `Texture` + オーバーレイ UI の組み立て。縦横レイアウト切替、`RotatedBox` によるプレビュー回転(§4.1) |
| `EraSlider` | Dart | 非線形年代スライダー widget。値は西暦年(10年量子化)で公開 |
| `ShutterButton` | Dart | シャッター/録画モード切替付きボタン |
| `CameraState` / `CameraNotifier` | Dart | アプリ状態(選択年、モード、録画中か、初期化状態、画面向き)。CameraState は Freezed の不変クラス、CameraNotifier は Riverpod の `Notifier<CameraState>` |
| `EraFilter` | Dart | **純粋関数**: 西暦年 → `FilterParams`。キーフレームテーブルと補間(03 参照) |
| `NativeCameraApi` | Dart | Platform Channel の型安全ラッパー。Dart 側で唯一 channel に触るクラス |
| `CameraController`(native) | Swift/Kotlin | カメラセッション管理、フレーム供給、静止画キャプチャ |
| `FilterRenderer`(native) | Swift/Kotlin | 毎フレーム: 入力フレーム + 最新 FilterParams → フィルタ済みフレーム。プレビュー/写真/録画で共用 |
| `MediaWriter`(native) | Swift/Kotlin | 写真のギャラリー保存、(P2)動画エンコード |

### 設計原則

1. **ネイティブは「年代」を知らない。** 受け取るのは raw な `FilterParams` のみ。
2. **FilterRenderer は 1 実装 3 用途。** プレビュー・静止画・録画で同一シェーダー/同一パラメータを使い、
   「撮れたものがプレビューと違う」事故を構造的に防ぐ。
3. **状態管理は Riverpod(`flutter_riverpod`)、モデルは Freezed の不変クラス**(§5.1)。
   パフォーマンス規約: `Texture` を含むプレビュー部は状態に依存させず一度だけ build し、
   スライダー操作(60Hz)で再ビルドされるのは年代ラベルとスライダー自身のみとする
   (`ref.watch(provider.select(...))` を使う。プレビュー全体の再ビルドは禁止)。
   コード生成は Freezed のみ。riverpod_generator・flutter_hooks は使わない
   (provider は手書きし、実装 LLM のブレ要因になる魔法を減らす)。
4. ライフサイクル: アプリが background / 画面非表示になったら必ず `pausePreview`、
   復帰で `resumePreview`(GPU・カメラの無駄な占有と発熱を防ぐ)。Dart 側
   `WidgetsBindingObserver` で駆動する。

## 2. FilterParams 構造体

Dart → ネイティブへ送る唯一のフィルタ情報。**全 20 フィールド、すべて `double`**、
値域 [0,1](明記あるものを除く)。ネイティブ側はこれをそのままシェーダー uniform にマップする。

```dart
class FilterParams {
  final double monochrome;    // 0=カラー 1=完全モノクロ
  final double sepia;         // セピア調強度
  final double saturation;    // 彩度スケール 0..2 (1=変化なし)
  final double contrast;      // コントラストスケール 0.5..1.5 (1=変化なし)
  final double brightness;    // 明度オフセット -0.3..0.3 (0=変化なし)
  final double warmth;        // 色温度シフト -1(青)..1(アンバー)
  final double fade;          // 黒浮き(退色プリント表現)
  final double grain;         // 粒状ノイズ強度
  final double grainSize;     // 粒の大きさ 1..4 (px 単位系数)
  final double vignette;      // 周辺減光
  final double scratches;     // 縦傷の量(フィルム傷)
  final double dust;          // ダスト/斑点の量
  final double jitter;        // フレームの微小揺れ+映写フリッカー(古い映写機表現)
  final double halation;      // ハイライト滲み
  final double blur;          // 全体の甘さ(古レンズ表現)
  final double orthochromatic;// 整色乾板表現 0..1 (赤が黒く沈み空が白飛びする古写真の分光特性)
  final double engraving;     // 版画モード合成率 0..1 (1500-1840年代)
  final double hatchScale;    // 版画の線密度係数 0.5..1.0 (1=銅版の細密線, 0.5=木版の太い線)
  final double inkPainting;   // 絵巻/墨画モード合成率 0..1 (1000-1500年)
  final double paperTexture;  // 紙テクスチャ合成率
}
```

- **実装は Freezed**: `const factory FilterParams({...})` + private コンストラクタ
  `const FilterParams._();` を持たせ、`toMap()`(キーはフィールド名と完全一致)・
  `static FilterParams lerp(a, b, t)`・`static const neutral` をクラス内に定義する。
  フィールド名・宣言順は上記コードを正とする(ネイティブの uniform 順もこの順)。
- **中立値(= 無加工)の定義**: `saturation = contrast = grainSize = hatchScale = 1.0`、
  **他の 16 フィールドは 0.0**。`filter_params.dart` に `FilterParams.neutral` 定数として実装する。
- **ネイティブ側の初期値は必ずこの中立値とする。** 最初の `setFilterParams` 受信までは
  パススルー描画になる。**全ゼロ初期化は禁止**(saturation=0 はグレー一色の誤描画になる)。
- Map 化キーは **フィールド名と完全一致**(例: `{"monochrome": 0.0, "sepia": 0.4, ...}`)。
- **型規約**: 20 値はすべて Dart の `double` として送る(`toMap()` では `0` ではなく `0.0` を
  用いる)。Android 側は数値が Int/Long/Double のいずれで届いても読めるよう
  `(v as Number).toDouble()` で読むこと。
- 送信頻度: 値が変化したときのみ。ドラッグ中は Dart 側で 1 フレーム(16ms)にスロットリング。
- ネイティブは最後に受信した値を保持し毎フレーム適用する(受信スレッド→レンダースレッドは
  atomic な参照差し替えで渡す)。

## 3. Platform Channel API

### 3.1 MethodChannel: `historical_camera/method`

すべて Dart → ネイティブ呼び出し。エラーは `PlatformException(code, message)` で返す。
エラーコード: `CAMERA_PERMISSION_DENIED`, `CAMERA_UNAVAILABLE`, `CAPTURE_FAILED`,
`SAVE_FAILED`, `RECORDING_FAILED`, `BAD_STATE`。

| メソッド | 引数 (Map) | 戻り値 | 説明 |
|---------|-----------|--------|------|
| `initialize` | `{"lens": "back"\|"front", "resolutionPreset": "auto"\|"hd720"\|"hd1080"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int, "quarterTurns": int}` | カメラセッション構築→テクスチャ登録。**権限要求は Dart 側(permission_handler)が事前に行い**、ネイティブは権限状態を確認して未許可なら `CAMERA_PERMISSION_DENIED` を返すのみ。preview サイズは**初期化時に確定し以後不変**(向きの扱いは §4.1: iOS はセンサー横長、Android は自然向き)。quarterTurns は現在の表示回転。`"auto"`(P1 以降の Dart 既定)はネイティブが 1080p 実測ゲートの永続化結果(01 §1.1)で hd720/hd1080 に解決する(結果未保存時は hd720) |
| `setFilterParams` | FilterParams の Map(§2) | `null` | 最新フィルタパラメータの差し替え |
| `capturePhoto` | `{}` | `{"path": String, "width": int, "height": int}` | フル解像度静止画に現在の FilterParams を適用しギャラリー保存。戻りの path は**アプリ一時ディレクトリ内のファイルの絶対パス**(共有用。両 OS 共通の意味)。呼び出し中の多重呼び出しは `BAD_STATE` |
| `startRecording` | `{}` | `null` | (P2) 録画開始。未実装フェーズでは `RECORDING_FAILED`/"not implemented" を返す |
| `stopRecording` | `{}` | `{"path": String, "durationMs": int}` | (P2) 録画停止・ギャラリー保存 |
| `pausePreview` | `{}` | `null` | セッション停止(カメラ・GPU解放はしない) |
| `resumePreview` | `{}` | `null` | セッション再開 |
| `setZoom` | `{"zoom": double}` | `null` | (任意・P1) 1.0〜maxZoom |
| `setDebugStatsEnabled` | `{"enabled": bool}` | `null` | (P1) デバッグ画面(04 §8)表示中のみ有効化。有効中はネイティブが `debugStats` イベントを 1 秒ごとに送出する。既定は無効(通常動作に計測オーバーヘッドを載せない) |
| `switchLens` | `{"lens": "back"\|"front"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int, "quarterTurns": int}` | (任意・P1) レンズ切替。textureId は変わり得る |
| `openGallery` | `{}` | `null` | (P1) OS のフォトアプリ(ギャラリー)を開く。保存サムネイル(04 §4)のタップ動作。カメラ状態に依存せず `initialize` 前でも呼び出し可 |
| `dispose` | `{}` | `null` | 全リソース解放 |

OS のアプリ設定画面を開く操作(permissionDenied 画面の「設定を開く」)は自前メソッドではなく
**permission_handler の `openAppSettings()`** を使う(§5.1)。

**呼び出し順序の規約**: `initialize` の完了前に他メソッド(`dispose`・`openGallery` を除く)を呼んだ場合、
ネイティブは `BAD_STATE` を返す。`initialize` の 2 引数は必須・非 null
(Dart ラッパー `NativeCameraApi` がデフォルト `lens:"back"`, `resolutionPreset:"hd720"` を補う)。
textureId など整数は Android では Long で届くことに注意。

**resolutionPreset の意味(P0 実装の実測を踏まえて確定)**: `"hd720"`/`"hd1080"` は
「長辺 ≈1280 / ≈1920 の解像度要求」であり、**実際に得られる解像度・アスペクト比は
端末依存の交渉結果**(16:9 とは限らない。例: Pixel 6 は hd720 要求に対し 1280×960 の 4:3)。
戻り値 `previewWidth/Height` が唯一の正であり、Dart・ネイティブとも交渉結果が
どんなアスペクトでも成立するように書く(cover 表示 — 04 §1.3、バッファ寸法固定 — §4.1、
GPU 予算の実測は実交渉解像度で行う — 01 §1)。アスペクトの OS 間・機種間一致は
仕様として要求しない。

### 3.2 EventChannel: `historical_camera/event`

ネイティブ → Dart の通知ストリーム。イベントは Map で `{"type": String, ...}`。

| type | 追加フィールド | 発生タイミング |
|------|---------------|---------------|
| `initialized` | — | セッション開始完了(補助通知。下記参照) |
| `orientationChanged` | `quarterTurns: int (0..3)` | 表示回転の変化時(§4.1)。Dart は `RotatedBox` を更新する |
| `photoSaved` | `path` | ギャラリー保存完了(capturePhoto の戻り後に非同期で来る場合あり) |
| `thermal` | `level: String ("nominal"\|"fair"\|"serious"\|"critical")` | 端末の熱状態変化時(§6.1) |
| `recordingProgress` | `elapsedMs: int` | (P2) 録画中 1 秒ごと |
| `debugStats` | `gpuMs: double` | (P1) `setDebugStatsEnabled(true)` 中、1 秒ごと。直近フレームのフィルタ GPU 時間(計測は 01 §1.1 と同じ API を使用) |
| `error` | `code`, `message` | 実行時エラー(セッション中断・ディスクフル等)。例外として `ROTATION_MODEL_MISMATCH`(Android の回転モデル自己診断 — 06 §3.3・P1)は**診断専用(非致命)**であり、Dart は UI 状態を変えずログ記録のみ行う |

- **購読順序**: Dart は `initialize` を呼ぶ**前に** EventChannel の listen を開始すること。
  ネイティブは `onListen` 前に発生したイベントを破棄してよい(バッファリング不要)。
- **`initialized` の位置づけ**: 状態遷移(→previewing)は `initialize()` の Future 完了
  (textureId 受領)**のみ**で判定する。`initialized` イベントは補助であり、P0 では
  発火しなくてもよい。Dart はこのイベントに依存したロジックを書かないこと。
- **`photoSaved` の位置づけ**: UI の状態遷移([capturing]→[previewing])とシャッター連打
  保護の解除は **`capturePhoto` の Future 完了のみ**で行う。`photoSaved` はギャラリー反映の
  通知であり、P0 では未ハンドリングでも動作に支障がないこと(P1 の保存サムネイル更新で使う)。

### 3.3 Dart ラッパー `NativeCameraApi` の要件

- 上記を型付きメソッドとして提供: `Future<PreviewInfo> initialize(...)`,
  `Future<void> setFilterParams(FilterParams p)`, `Future<CapturedPhoto> capturePhoto()`, ...
- `setFilterParams` は内部でスロットリング(直近送信から 16ms 未満なら最新値を保留し
  タイマーで送る。**必ず最後の値が送られること**)。
- イベントは `Stream<CameraEvent>` として公開。CameraEvent は **Freezed の sealed union**
  (`initialized` / `orientationChanged` / `photoSaved` / `thermal` / `recordingProgress` /
  `debugStats`(P1)/ `error`)として定義し、switch 式で網羅チェックが効くようにする。

## 4. プレビュー描画の流れ(共通シーケンス)

```
カメラフレーム到着 (30fps, ネイティブのキャプチャスレッド)
  → FilterRenderer.render(frame, latestParams)   // GPU。2〜6ms @720p
  → 出力を Flutter 外部テクスチャへ書き込み
  → textureFrameAvailable 通知 → Flutter が Texture widget を再描画
```

- Dart はフレームごとの処理を**一切行わない**(スライダー操作時に params を送るだけ)。
- 静止画: `capturePhoto` → ネイティブがフル解像度キャプチャ → 正立向きに回転(§4.1)→
  **同じ FilterRenderer** をフル解像度で 1 回実行 → JPEG エンコード(品質 0.9)→
  EXIF(撮影日時・Orientation `.up`)付与 → ギャラリー保存。プレビューは止めない。
- 録画(P2): プレビューと同じフィルタ済みフレームをエンコーダ入力へ分岐(07 参照)。

### 4.1 回転モデル(P0 実装で実挙動に合わせて改訂)

回転の扱いは実装事故が最も起きやすい箇所。次のモデルに固定する。
不変条件は両 OS 共通、バッファの向きだけが OS で異なる(implementation-notes #3)。

**不変条件(共通)**

1. **出力バッファの寸法は初期化時に一度だけ決まり、以後不変。** 回転でバッファ・
   プール・テクスチャを作り直さない。`previewWidth/Height` は初期化時に一度返すのみ。
2. quarterTurns =「テクスチャを表示上正立させるために時計回りに 90°×N 回転させる数」
   (0..3)。変化時に `orientationChanged {quarterTurns}` を Dart へ通知する。
   フロントカメラのミラーはネイティブが吸収し、quarterTurns の意味は前後カメラで同一。
3. **Dart 側は `RotatedBox(quarterTurns:)` で Texture を回転**し、
   `previewWidth:previewHeight` のアスペクト比を維持したまま `FittedBox(fit: cover)` で
   全画面表示する(04 §1.3)。
4. シェーダーには uniform `orientation`(= quarterTurns)を渡し、方向依存エフェクト
   (縦傷・版画の斜線)を表示上の向きに合わせる(03 §3)。
5. 静止画はフィルタ適用**前に**正立ピクセルにし(`orientation` uniform は 0)、
   EXIF Orientation は `.up`。フロントカメラの静止画は**プレビューと同じ鏡像で保存**。

**バッファの向き(OS 別)**

- **iOS**: バッファはセンサー向き(横長)のまま。ネイティブはバッファを回転しない。
  quarterTurns はデバイス向きから算出(landscapeLeft=0, portrait=1, ...)。
- **Android**: HAL がセンサー回転を SurfaceTexture の transform 行列に常時焼き込むため、
  サンプル後のコンテンツは**自然向き(縦)で正立**になる。したがって出力バッファは
  **回転後の寸法(例 960x1280)**で確保する。quarterTurns はディスプレイ回転の打ち消し
  (`(-displayRotation/90) mod 4`)で、`DisplayManager.DisplayListener` で追従する。
  CameraX の `preview.targetRotation` は**センサー向きに固定**する(targetRotation に
  追従させると transform が変化し、固定寸法バッファでアスペクトが崩れるため)。
  この焼き込み前提は HAL 依存のため、初回フレームで transform 行列を検査する自己診断を
  P1 で入れる(06 §3.3)。詳細は 06 §3.1/§3.3。

## 5. Flutter プロジェクト構成

```
historical_camera/
├── pubspec.yaml            # 依存は §5.1 の採用パッケージのみ
├── lib/
│   ├── main.dart               # ProviderScope + MaterialApp, 画面向き設定
│   ├── strings.dart            # 表示文言の集約(将来の i18n に備える)
│   ├── domain/
│   │   ├── filter_params.dart  # FilterParams(§2。Freezed)+ toMap() + neutral + lerp
│   │   ├── era_filter.dart     # 年代→FilterParams 変換(03 の実装)
│   │   └── era_scale.dart      # スライダー位置↔西暦年の非線形変換(04 の実装)
│   ├── platform/
│   │   ├── camera_event.dart   # CameraEvent(Freezed sealed union — §3.3)
│   │   └── native_camera_api.dart  # §3 のラッパー
│   ├── state/
│   │   └── camera_state.dart   # CameraState(Freezed)+ CameraNotifier + provider 定義
│   └── ui/
│       ├── camera_screen.dart  # 全体レイアウト(04)。ConsumerWidget
│       ├── era_slider.dart
│       ├── shutter_button.dart
│       └── era_label.dart      # 現在年の大きな表示
├── ios/Runner/
│   ├── AppDelegate.swift       # plugin 登録
│   └── HistoricalCamera/       # 05 参照
│       ├── HistoricalCameraPlugin.swift
│       ├── CameraController.swift
│       ├── FilterRenderer.swift
│       ├── Shaders.metal
│       ├── FilterParams.swift
│       └── MediaWriter.swift
└── android/app/src/main/kotlin/.../historicalcamera/   # 06 参照
    ├── HistoricalCameraPlugin.kt
    ├── CameraController.kt
    ├── FilterRenderer.kt       # GL 描画 + シェーダー文字列
    ├── FilterParams.kt
    └── MediaWriter.kt
```

### 5.1 採用パッケージ(この表以外は追加しない)

知名度・安定性が高く、パフォーマンスを損なわず保守性を上げるものだけを採用する。

| パッケージ | 用途 | 採用理由 |
|-----------|------|---------|
| `flutter_riverpod` | 状態管理・DI | コンパイルセーフ。`select` で再ビルド範囲を最小化(設計原則3)。テスト時の provider 差し替えが容易 |
| `freezed` + `freezed_annotation` | 不変モデル(FilterParams / CameraState / CameraEvent) | copyWith・==・sealed union の boilerplate 削減。20 フィールドの手書きミスを排除 |
| `permission_handler` | カメラ・マイク・(API28 以下)ストレージの権限要求、`openAppSettings()` | ネイティブの権限プラミング(特に Android の ActivityAware 経由の要求フロー)を丸ごと置き換え |
| `wakelock_plus` | プレビュー中の画面スリープ防止 | ネイティブ両実装(isIdleTimerDisabled / FLAG_KEEP_SCREEN_ON)を置き換え |
| `build_runner`(dev) | Freezed のコード生成 | — |
| `flutter_lints`(dev) | 静的解析 | Flutter 標準 |
| `mocktail`(dev) | テストのモック | null-safety 対応の事実上標準 |

- **不採用と理由**: `camera`(自前パイプラインと衝突)/ `riverpod_generator`・
  `flutter_hooks`(魔法・パラダイム追加は実装 LLM のブレ要因)/ `bloc`(Riverpod と重複)/
  `go_router`(1 画面のため不要)/ `GetX`(設計方針と不一致)。
- **バージョン方針**: プロジェクト開始時(T1)に各パッケージの最新 stable を確認して
  `^` で pubspec に固定し、README に記録する(08 §4 の Flutter バージョン固定と同時に行う)。
- カメラ・フィルタ・保存のパイプラインは引き続き自前ネイティブ(§1)。パッケージ採用は
  Dart 層のみに影響し、Platform Channel API・ネイティブ実装には影響しない。

## 6. スレッド/キュー設計(ネイティブ共通)

| スレッド | 役割 |
|---------|------|
| メイン | channel 応答、セッション構成 |
| キャプチャ(camera queue) | フレーム受領。**ここでは重い処理をしない** |
| レンダー(GPU queue / GLThread) | FilterRenderer 実行(プレビュー)、テクスチャ書き込み、(P2)エンコーダ供給 |
| 静止画レンダー | フル解像度フィルタ適用。**プレビューのレンダースレッドとは分離**(iOS: 専用 MTLCommandQueue / Android: 共有コンテキストの第 2 GL スレッド。05/06 参照) |
| 書き込み | 写真エンコード・ファイル IO(静止画は一時的でよい) |

FilterParams の受け渡し: メインスレッドで受信 → イミュータブルな構造体を作り
atomic に差し替え → レンダースレッドは毎フレーム最新参照を読む。ロック不要。

### 6.1 サーマル(熱)対応

連続プレビューはカメラ ISP + GPU の常時稼働であり、屋外では数分〜10 分で
サーマルスロットリングに入り得る。P0 から次を実装する:

- iOS: `ProcessInfo.thermalStateDidChangeNotification` / Android: `PowerManager.addThermalStatusListener` を購読し、EventChannel `thermal` イベントに変換する。
- `serious`(Android: `THERMAL_STATUS_SEVERE`)以上で、ネイティブが自動的に
  カメラフレームレートを 24fps へ低減する(1080p 動作中なら 720p へ降格)。
  Dart 側は `thermal` イベントで軽量な注意表示を出せる(表示は P1 でよい)。
