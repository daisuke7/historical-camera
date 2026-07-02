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
| `CameraScreen` | Dart | 全画面 `Texture` + オーバーレイ UI の組み立て。縦横レイアウト切替 |
| `EraSlider` | Dart | 非線形年代スライダー widget。値は西暦年(10年量子化)で公開 |
| `ShutterButton` | Dart | シャッター/録画モード切替付きボタン |
| `CameraState` | Dart | アプリ状態(選択年、モード、録画中か、初期化状態)。`ChangeNotifier` |
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

Dart → ネイティブへ送る唯一のフィルタ情報。全フィールド `double`、値域 [0,1]
(明記あるものを除く)。ネイティブ側はこれをそのままシェーダー uniform にマップする。

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
  final double jitter;        // フレームの微小揺れ(古い映写機表現)
  final double halation;      // ハイライト滲み
  final double blur;          // 全体の甘さ(古レンズ表現)
  final double engraving;     // 版画モード合成率 0..1 (1500-1840年代)
  final double inkPainting;   // 絵巻/墨画モード合成率 0..1 (1000-1500年)
  final double paperTexture;  // 紙テクスチャ合成率
}
```

- Map 化キーは **フィールド名と完全一致**(例: `{"monochrome": 0.0, "sepia": 0.4, ...}`)。
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
| `initialize` | `{"lens": "back"\|"front", "resolutionPreset": "hd720"\|"hd1080"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int}` | 権限確認→カメラセッション構築→テクスチャ登録。preview サイズはセンサー向き基準(横長) |
| `setFilterParams` | FilterParams の Map(§2) | `null` | 最新フィルタパラメータの差し替え |
| `capturePhoto` | `{}` | `{"path": String, "width": int, "height": int}` | フル解像度静止画に現在の FilterParams を適用しギャラリー保存。戻りの path は保存後の一時ファイル(共有用)。呼び出し中の多重呼び出しは `BAD_STATE` |
| `startRecording` | `{}` | `null` | (P2) 録画開始。未実装フェーズでは `RECORDING_FAILED`/"not implemented" を返す |
| `stopRecording` | `{}` | `{"path": String, "durationMs": int}` | (P2) 録画停止・ギャラリー保存 |
| `pausePreview` | `{}` | `null` | セッション停止(カメラ・GPU解放はしない) |
| `resumePreview` | `{}` | `null` | セッション再開 |
| `setZoom` | `{"zoom": double}` | `null` | (任意・P1) 1.0〜maxZoom |
| `switchLens` | `{"lens": "back"\|"front"}` | `{"textureId": int, "previewWidth": int, "previewHeight": int}` | (任意・P1) レンズ切替。textureId は変わり得る |
| `dispose` | `{}` | `null` | 全リソース解放 |

### 3.2 EventChannel: `historical_camera/event`

ネイティブ → Dart の通知ストリーム。イベントは Map で `{"type": String, ...}`。

| type | 追加フィールド | 発生タイミング |
|------|---------------|---------------|
| `initialized` | — | セッション開始完了 |
| `photoSaved` | `path` | ギャラリー保存完了(capturePhoto の戻り後に非同期で来る場合あり) |
| `recordingProgress` | `elapsedMs: int` | (P2) 録画中 1 秒ごと |
| `error` | `code`, `message` | 実行時エラー(セッション中断・ディスクフル等) |

### 3.3 Dart ラッパー `NativeCameraApi` の要件

- 上記を型付きメソッドとして提供: `Future<PreviewInfo> initialize(...)`,
  `Future<void> setFilterParams(FilterParams p)`, `Future<CapturedPhoto> capturePhoto()`, ...
- `setFilterParams` は内部でスロットリング(直近送信から 16ms 未満なら最新値を保留し
  タイマーで送る。**必ず最後の値が送られること**)。
- イベントは `Stream<CameraEvent>` として公開。

## 4. プレビュー描画の流れ(共通シーケンス)

```
カメラフレーム到着 (30fps, ネイティブのキャプチャスレッド)
  → FilterRenderer.render(frame, latestParams)   // GPU。2〜6ms
  → 出力を Flutter 外部テクスチャへ書き込み
  → textureFrameAvailable 通知 → Flutter が Texture widget を再描画
```

- Dart はフレームごとの処理を**一切行わない**(スライダー操作時に params を送るだけ)。
- 静止画: `capturePhoto` → ネイティブがフル解像度キャプチャ → **同じ FilterRenderer** を
  フル解像度で 1 回実行 → JPEG エンコード(品質 0.9)→ EXIF(撮影日時・Orientation)付与 →
  ギャラリー保存。プレビューは止めない。
- 録画(P2): プレビューと同じフィルタ済みフレームをエンコーダ入力へ分岐(07 参照)。

## 5. Flutter プロジェクト構成

```
historical_camera/
├── pubspec.yaml            # 依存: 最小限。permission_handler のみ検討(なくても可: ネイティブで権限処理)
├── lib/
│   ├── main.dart               # MaterialApp, 画面向き設定
│   ├── domain/
│   │   ├── filter_params.dart  # FilterParams(§2) + toMap()
│   │   ├── era_filter.dart     # 年代→FilterParams 変換(03 の実装)
│   │   └── era_scale.dart      # スライダー位置↔西暦年の非線形変換(04 の実装)
│   ├── platform/
│   │   └── native_camera_api.dart  # §3 のラッパー
│   ├── state/
│   │   └── camera_state.dart   # ChangeNotifier(選択年, モード, 録画状態, 初期化状態)
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
自前ネイティブで持つため衝突する)。権限もネイティブ側で要求すれば Dart 依存ゼロにできる。

## 6. スレッド/キュー設計(ネイティブ共通)

| スレッド | 役割 |
|---------|------|
| メイン | channel 応答、セッション構成 |
| キャプチャ(camera queue) | フレーム受領。**ここでは重い処理をしない** |
| レンダー(GPU queue / GLThread) | FilterRenderer 実行、テクスチャ書き込み、(P2)エンコーダ供給 |
| 書き込み | 写真エンコード・ファイル IO(静止画は一時的でよい) |

FilterParams の受け渡し: メインスレッドで受信 → イミュータブルな構造体を作り
atomic に差し替え → レンダースレッドは毎フレーム最新参照を読む。ロック不要。
