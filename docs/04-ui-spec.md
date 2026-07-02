# 04. 画面・UX 仕様

画面は 1 枚(`CameraScreen`)のみ。設定・ギャラリーは初回リリーススコープ外
(保存後は OS の写真アプリで見る)。

## 1. レイアウト

### 1.1 縦向き (portrait)

```
┌──────────────────────────────┐
│ ステータスバー(透過)            │
│                              │
│        [ 1970年代 ]  ← 年代ラベル(上部中央, 操作時のみ表示) │
│                              │
│                              │
│      カメラプレビュー           │
│      (Texture, 全画面)     ┌─┐│
│                           │●│← シャッターボタン(右端・垂直中央)
│                           └─┘│
│                     [写真|動画]← モード切替(ボタン下)
│                              │
│ ├────────○─────┤            │
│ 1000        1970    現在      ← 年代スライダー(下部)
└──────────────────────────────┘
```

### 1.2 横向き (landscape)

プレビューは全画面のまま。スライダーは下辺に横のまま、シャッターは右辺中央
(縦持ちと同じ「下=スライダー / 右=シャッター」の関係を維持)。

### 1.3 共通ルール

- プレビューは `Texture` widget を `FittedBox(fit: BoxFit.cover)` 相当で全画面カバー表示
  (アスペクト比が合わない分は切れてよい)。
- UI オーバーレイは `SafeArea` 内に配置。背景に半透明黒(α0.25)のグラデーションを
  スライダー帯・ボタン帯の背後に敷き、白 UI の視認性を確保する。
- 回転: `OrientationBuilder` でレイアウト切替。プレビューの回転補正はネイティブ側の責務
  (Flutter 側では何もしない)。回転中もプレビューは止めない。

## 2. 年代スライダー `EraSlider`

### 2.1 スケール(非線形)

直近 100 年に見た目変化が集中するため、トラックの半分を直近 100 年に割り当てる。
位置 `p`(0=左端, 1=右端)と西暦年の**区分線形**変換(`era_scale.dart` に実装):

| p 区間 | year 区間 | 意図 |
|--------|----------|------|
| 0.50 – 1.00 | (now−100) – now | 写真の時代の濃い変化に半分を割く |
| 0.20 – 0.50 | 1500 – (now−100) | 版画の時代 |
| 0.00 – 0.20 | 1000 – 1500 | 絵巻の時代 |

```dart
double yearForPosition(double p, int nowYear);   // 上表の区分線形補間
double positionForYear(double year, int nowYear); // 逆変換(往復で誤差 <0.5 年をテスト)
```

### 2.2 値の扱い

- ドラッグ中: 連続値 `year` をそのまま `EraFilter` に渡す(見た目が滑らかに変化)。
- 表示・確定値: `quantizedYear = min(nowYear, (year / 10).round() * 10)`(10 年単位)。
  右端だけは「現在」と表示。
- 指を離したとき: `quantizedYear` の位置にスナップ(150ms の easeOut アニメーション)。
- 10 年境界をまたぐたびに軽いハプティクス(`HapticFeedback.selectionClick`)。
- 目盛り: 100 年ごとに小さな目盛り線、1000/1500/1900/現在 にラベル。

### 2.3 実装方針

標準 `Slider` は使わず `GestureDetector` + `CustomPaint` で自作する
(非線形目盛り・スナップ・帯デザインのため)。widget の公開 API:

```dart
EraSlider(
  year: double,                  // 現在値(連続)
  nowYear: int,
  onChanged: (double year),      // ドラッグ中、連続値
  onChangeEnd: (int quantizedYear),
)
```

## 3. 年代ラベル `EraLabel`

- 画面上部中央。`1970年代` / `1500年ごろ`(1840 以前は「ごろ」表記)/ `現在`。
- スライダー操作中+操作後 1.5 秒表示し、フェードアウト(300ms)。
- 補助テキスト(小): 世代の説明。例 `モノクロ写真の時代` / `版画の時代` / `絵巻の時代`。

## 4. シャッターボタン `ShutterButton`

- 直径 72dp の円形。写真モード: 白リング+白丸。動画モード: 白リング+赤丸。
- タップ(写真): 撮影 → 画面全体を白フラッシュ(120ms)→ 左下に保存サムネイル
  (直近の保存画像、タップで OS フォトアプリを開く。P1)。
- タップ(動画・P2): 録画開始 → ボタンが赤角丸四角に変形、上部に `● 00:12` の経過表示。
  再タップで停止・保存。**録画中もスライダー操作可能**(仕様要件)。
- モード切替: ボタン下(横向き時はボタン左)の `写真 | 動画` セグメント。録画未実装の
  フェーズでは動画側を非表示にする(グレーアウトではなく非表示)。
- 連打保護: `capturePhoto` の Future 完了まで再タップ無効(ボタンを 40% 透明化)。

## 5. 状態遷移(`CameraState`)

```
[uninitialized]
   → initialize() 呼び出し → [initializing]
       → 成功(textureId 受領) → [previewing]
       → 権限拒否 → [permissionDenied]   … 説明+「設定を開く」ボタンの全画面表示
       → 失敗 → [error]                  … メッセージ+再試行ボタン
[previewing]
   → capturePhoto → [capturing](プレビュー継続・UI ロックのみ) → 完了 → [previewing]
   → startRecording → [recording] → stopRecording → [previewing]
   → アプリ background / 非表示 → pausePreview → [paused] → 復帰 → resumePreview → [previewing]
```

`CameraState`(ChangeNotifier)の保持フィールド:
`phase`(上記列挙)、`year`(double)、`quantizedYear`(int)、`mode`(photo/video)、
`textureId`、`previewSize`、`recordingElapsed`、`lastSavedPath`。

## 6. 文言・その他

- 権限説明(iOS Info.plist / Android): 「昔の見た目を再現するためにカメラを使用します」等。
- 対応言語: 初回は日本語のみ。文字列は 1 ファイル(`strings.dart`)に集約し将来の i18n に備える。
- 画面スリープ: プレビュー中は無効化(wakelock)。ネイティブ側で
  `isIdleTimerDisabled` / `FLAG_KEEP_SCREEN_ON` を制御(依存パッケージ削減のため)。
