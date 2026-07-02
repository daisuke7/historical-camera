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
| `CameraState` | Dart | アプリ状態(選択年、モード、録画中か、初期化状態、画面向き)。`ChangeNotifier` |
| `EraFilter` | Dart | **純粋関数**: 西暦年 → `FilterParams`。キーフレームテーブルと補間(03 参照) |
| `NativeCameraApi` | Dart | Platform Channel の型安全ラッパー。Dart 側で唯一 channel に触るクラス |
| `CameraController`(native) | Swift/Kotlin | カメラセッション管理、フレーム供給、静止画キャプチャ |
| `FilterRenderer`(native) | Swift/Kotlin | 毎フレーム: 入力フレーム + 最新 FilterParams → フィルタ済みフレーム。プレビュー/写真/録画で共用 |
| `MediaWriter`(native) | Swift/Kotlin | 写真のギャラリー保存、(P2)動画エンコード |

### 設計原則

1. **ネイティブは「年代」を知らない。** 受け取るのは raw な `FilterParams` のみ。
2. **FilterRenderer は 1 実装 3 用途。** プレビュー・静止画・録画で同一シェーダー/同一パラメータを使い、
   「撮れたものがプレビューと違う」事故を構造的に防ぐ。
3. **状態管理は素の `ChangeNotifier` + `ListenableBuilder`。** 外部状態管理パッケージは使わない
   (依存を減らし、低レベル LLM の実装ブレを防ぐ)。
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
| `initialize` | `{"lens": "back"\|"front", "resolutionPreset": "hd720"\|"hd1080"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int, "quarterTurns": int}` | 権限確認→カメラセッション構築→テクスチャ登録。preview サイズは**センサー向き基準(横長)で固定**(§4.1)。quarterTurns は現在の表示回転 |
| `setFilterParams` | FilterParams の Map(§2) | `null` | 最新フィルタパラメータの差し替え |
| `capturePhoto` | `{}` | `{"path": String, "width": int, "height": int}` | フル解像度静止画に現在の FilterParams を適用しギャラリー保存。戻りの path は**アプリ一時ディレクトリ内のファイルの絶対パス**(共有用。両 OS 共通の意味)。呼び出し中の多重呼び出しは `BAD_STATE` |
| `startRecording` | `{}` | `null` | (P2) 録画開始。未実装フェーズでは `RECORDING_FAILED`/"not implemented" を返す |
| `stopRecording` | `{}` | `{"path": String, "durationMs": int}` | (P2) 録画停止・ギャラリー保存 |
| `pausePreview` | `{}` | `null` | セッション停止(カメラ・GPU解放はしない) |
| `resumePreview` | `{}` | `null` | セッション再開 |
| `setZoom` | `{"zoom": double}` | `null` | (任意・P1) 1.0〜maxZoom |
| `switchLens` | `{"lens": "back"\|"front"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int, "quarterTurns": int}` | (任意・P1) レンズ切替。textureId は変わり得る |
| `openAppSettings` | `{}` | `null` | OS のアプリ設定画面を開く(iOS: `UIApplication.openSettingsURLString`、Android: `ACTION_APPLICATION_DETAILS_SETTINGS` + package URI の Intent)。permissionDenied 画面の「設定を開く」ボタンから呼ぶ |
| `dispose` | `{}` | `null` | 全リソース解放 |

**呼び出し順序の規約**: `initialize` の完了前に他メソッド(`dispose` を除く)を呼んだ場合、
ネイティブは `BAD_STATE` を返す。`initialize` の 2 引数は必須・非 null
(Dart ラッパー `NativeCameraApi` がデフォルト `lens:"back"`, `resolutionPreset:"hd720"` を補う)。
textureId など整数は Android では Long で届くことに注意。

### 3.2 EventChannel: `historical_camera/event`

ネイティブ → Dart の通知ストリーム。イベントは Map で `{"type": String, ...}`。

| type | 追加フィールド | 発生タイミング |
|------|---------------|---------------|
| `initialized` | — | セッション開始完了(補助通知。下記参照) |
| `orientationChanged` | `quarterTurns: int (0..3)` | 表示回転の変化時(§4.1)。Dart は `RotatedBox` を更新する |
| `photoSaved` | `path` | ギャラリー保存完了(capturePhoto の戻り後に非同期で来る場合あり) |
| `thermal` | `level: String ("nominal"\|"fair"\|"serious"\|"critical")` | 端末の熱状態変化時(§6.1) |
| `recordingProgress` | `elapsedMs: int` | (P2) 録画中 1 秒ごと |
| `error` | `code`, `message` | 実行時エラー(セッション中断・ディスクフル等) |

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
- イベントは `Stream<CameraEvent>` として公開。

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

### 4.1 回転モデル(両 OS 共通。厳守)

回転の扱いは実装事故が最も起きやすい箇所のため、次のモデルに固定する
(公式 camera プラグインと同方式)。

1. **プレビューバッファは常にセンサー向き(横長)固定。ネイティブはバッファを回転しない。**
   出力テクスチャ・バッファプールの寸法は初期化時から不変であり、
   `previewWidth/Height` も横長固定値を一度返すだけでよい。
2. ネイティブはデバイス向きを監視し、変化時に `orientationChanged {quarterTurns}` を
   Dart へ通知する。quarterTurns は「テクスチャを表示上正立させるために時計回りに
   90°×N 回転させる数」(0..3)。フロントカメラのミラーはネイティブが吸収し、
   quarterTurns の意味は前後カメラで同一とする。
3. **Dart 側は `RotatedBox(quarterTurns:)` で Texture を回転**し、
   `previewWidth:previewHeight` のアスペクト比を維持したまま `FittedBox(fit: cover)` で
   全画面表示する(04 §1.3)。
4. シェーダーには uniform `orientation`(= quarterTurns, 0..3)を渡す。方向依存の
   エフェクト(縦傷・版画の斜線・揺れ)は表示上の向きに合わせて描く(03 §3)。
5. 静止画はフィルタ適用**前に**ネイティブがピクセルを正立向きへ回転し(このとき
   `orientation` uniform は 0)、EXIF Orientation は `.up` を書く。
   フロントカメラの静止画は**プレビューと同じ鏡像で保存**する(「撮れたものが
   プレビューと一致」を優先)。

## 5. Flutter プロジェクト構成

```
historical_camera/
├── pubspec.yaml            # 依存: 最小限。権限もネイティブで処理し Dart 依存ゼロを基本とする
├── lib/
│   ├── main.dart               # MaterialApp, 画面向き設定
│   ├── strings.dart            # 表示文言の集約(将来の i18n に備える)
│   ├── domain/
│   │   ├── filter_params.dart  # FilterParams(§2) + toMap() + neutral 定数 + lerp
│   │   ├── era_filter.dart     # 年代→FilterParams 変換(03 の実装)
│   │   └── era_scale.dart      # スライダー位置↔西暦年の非線形変換(04 の実装)
│   ├── platform/
│   │   └── native_camera_api.dart  # §3 のラッパー
│   ├── state/
│   │   └── camera_state.dart   # ChangeNotifier(選択年, モード, 録画状態, 初期化状態, 向き)
│   └── ui/
│       ├── camera_screen.dart  # 全体レイアウト(04)
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

依存パッケージ方針: カメラ系プラグイン(`camera` 等)は**使わない**(パイプラインを
自前ネイティブで持つため衝突する)。権限・設定画面遷移・wakelock もネイティブ側で処理する。

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
