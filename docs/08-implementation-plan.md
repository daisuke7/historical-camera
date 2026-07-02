# 08. 実装計画 — フェーズ・タスク分解・受け入れ基準

## 1. フェーズ概要

| フェーズ | 内容 | 成果物 |
|---------|------|--------|
| P0 | コア体験: プレビュー+年代フィルター(全 18 パラメータ)+写真保存 | ストア審査に出せる最小アプリ |
| P1 | 磨き込み: レンズ切替・ズーム・保存サムネイル・非線形スライダー調整・実機チューニング・メディアフレーム演出(04 §7)・シャッター音の年代連動・版画の地域プリセット(和/洋。03 §5)・パラメータ直接操作のデバッグ隠し画面 | 初回リリース版 |
| P2 | 録画(07 の設計を実装)。候補: 長時間露光ゴースト(03 §5) | アップデート |
| P3 | セグメンテーション領域別エフェクト+クラウド生成 AI「タイムトラベル現像」 | アップデート |

## 2. P0 タスク分解(LLM に渡す単位)

依存関係順。各タスクは独立に完了検証できる。**[参照] は必ずコンテキストに含めるドキュメント**
(02 は全タスク共通で必須)。

### T1. Flutter プロジェクト雛形
- `flutter create historical_camera`(org は適宜)。02 §5 のディレクトリを空ファイルで作成。
- pubspec に 02 §5.1 の採用パッケージを追加(各パッケージの最新 stable を確認し `^` で固定、
  README に記録)。`main.dart` を `ProviderScope` でラップ。
- 縦横両対応(orientation 制限なし)、Material 3、ダークテーマ固定。
- [参照] 02

### T2. Dart ドメイン層
- `filter_params.dart`(FilterParams + `toMap()` + `lerp(a, b, t)` + `neutral` 定数)
- `era_filter.dart`(キーフレームテーブル + `paramsForYear`)
- `era_scale.dart`(`yearForPosition` / `positionForYear`)
- FilterParams は Freezed で実装(02 §2)。`dart run build_runner build` が通ること。
- 単体テスト: 03 §2.2 と 04 §2.1 に記載のケース。**このタスクはネイティブ不要で完結**。
- [参照] 02 §2, 03, 04

### T3. Dart プラットフォーム層 + 状態管理
- `camera_event.dart`(Freezed sealed union — 02 §3.3)
- `native_camera_api.dart`(channel ラッパー、16ms スロットリング、イベント Stream)
- `camera_state.dart`(CameraState(Freezed)+ CameraNotifier(Riverpod)。04 §5 の状態遷移。
  権限要求は initialize 前に permission_handler で行う)
- テスト: スロットリングが「最後の値を必ず送る」こと(fake channel で検証)。
  CameraNotifier の状態遷移(provider を差し替えたユニットテスト)。
- [参照] 02, 04

### T4. Flutter UI
- `camera_screen.dart` / `era_slider.dart` / `shutter_button.dart` / `era_label.dart` /
  `strings.dart`(文言集約)
- ConsumerWidget + `ref.watch(...select(...))` で再ビルド範囲を最小化
  (02 §1 設計原則3: プレビュー Texture 部はスライダー操作で再ビルドされないこと)。
- ネイティブ未完成でも動くよう、`textureId == null` の間は黒背景+起動スピナー表示。
- [参照] 02 §1, 04

### T5. iOS: パススルー表示
- Plugin 骨格、`initialize`、カメラ→無加工 Metal kernel→Texture 表示、pause/resume、dispose。
- 検証: iOS 実機でプレビュー全画面表示、回転が正しい。
- [参照] 05(§1-3, §4.1, §6)

### T6. iOS: フィルタシェーダー
- 03 §3 を MSL 移植。`setFilterParams` 経路。パススルー検証テスト。
- 検証: スライダーで色調が滑らかに変化。Xcode の GPU レポートでフレーム処理 <8ms。
- [参照] 03, 05(§4)

### T7. iOS: 写真保存
- `capturePhoto` フル解像度適用+PHPhotoLibrary 保存+EXIF。
- 検証: 保存写真がプレビューの見た目と一致(目視)。写真アプリで開ける。向き正しい。
- [参照] 03 §4, 05(§3.4, §5)

### T8. Android: パススルー表示
- Plugin 骨格、権限、GL スレッド+EGL、CameraX→OES→Flutter Texture。
- [参照] 06(§1-3 のパススルー部分, §6, §8)

### T9. Android: フィルタシェーダー
- 03 §3 を GLSL ES 3.0 移植(external/2D の 2 変種コンパイル)。
- 検証: `GL_TIMESTAMP` クエリまたは Android GPU Inspector でフィルタ描画時間を実測し、
  下位テスト機 @720p で 8ms 未満であること(iOS T6 と同水準の基準)。
- [参照] 03, 06(§3.1, §4)

### T10. Android: 写真保存
- `capturePhoto` + MediaStore 保存。
- [参照] 03 §4, 06(§3.4, §5)

### T11. 結合・ライフサイクル
- background/復帰、権限拒否画面(「設定を開く」= permission_handler の `openAppSettings()`)、
  エラーイベント表示、サーマルイベントと自動降格(02 §6.1)、wakelock_plus 制御、
  白フラッシュ演出。
- 回転の独立検証: **4 方向 × 前後カメラ × プレビュー/保存写真** の全組合せで向きと
  鏡像が正しいこと(回転は事故が最も多い箇所のため独立項目とする)。
- [参照] 02 §1(設計原則4)・§4.1・§6.1, 04 §5

## 3. P0 受け入れ基準(全体)

1. iPhone(実機)/ Android(実機)でプレビューが 30fps を維持(スライダー操作中も)
2. スライダーを右端→左端まで動かすと、カラー→退色→モノクロ→セピア→版画→絵巻と
   連続的に変化し、表現の不連続なジャンプがない
3. 右端で完全に無加工(現在)であること(`paramsForYear` の「nowYear 以上は中立値を返す」
   ショートカット(03 §2.2)により厳密に成立する)
4. シャッターで保存した写真がプレビューの見た目と一致し、OS のギャラリーに現れる
5. 縦横どちらでも UI が崩れず、保存写真の向きが正しい
6. background→復帰、権限拒否→設定から許可→復帰、の各シナリオでクラッシュしない
7. `flutter test` の単体テスト(T2, T3)が全て green

## 4. 開発環境セットアップ手順

1. Flutter SDK は **stable の 1 バージョンを選んで固定**し、プロジェクト README と
   pubspec の `environment`(例: `sdk: '>=3.5.0 <4.0.0'`)に記録する(fvm 推奨)。
   T8 の外部テクスチャ動作確認はこの固定バージョンに対して行い、以後むやみに上げない。
   + Android Studio(Flutter/Dart プラグイン)
2. iOS: Mac に Xcode をインストールし、`ios/Runner.xcworkspace` を一度開いて
   Signing & Capabilities で開発チームを設定(以後のビルドは
   Android Studio / `flutter run` から可能)
3. 実機必須: カメラ・GPU 検証はシミュレータ/エミュレータでは不可能。
   iOS 1 台 + Android 1 台(できれば GPU 性能の異なる 2 台)を用意

## 5. リスク登録簿

| リスク | 影響 | 兆候の検知 | 対応 |
|--------|------|-----------|------|
| Impeller と外部テクスチャの互換問題(Android) | プレビューが映らない | T8 のパススルー時点で判明 | SurfaceProducer(06 §3.1)が一次対応。それでも駄目な場合のみ Impeller 無効化で切り分け(06 §8)。Flutter バージョン固定 |
| 低性能端末でのフレーム落ち | 体験劣化 | T6/T9 の GPU 計測 | プレビュー解像度を 720p 未満に落とすフォールバック |
| 採用パッケージのメジャーバージョン差異(Riverpod/Freezed の API 変化) | 実装 LLM が古い API で書きビルドエラー | T1〜T4 のビルド | バージョンを `^` で固定(02 §5.1)。LLM へのタスク投入時は pubspec.yaml を必ず添付する |
| フィルタの「それっぽさ」不足 | 企画価値の毀損 | 実機での主観評価 | 03 のテーブルはチューニング前提。デバッグ用にパラメータを直接操作できる隠し画面を P1 で作る |
| capturePhoto の見た目不一致 | 信頼性低下 | T7/T10 検証 | 03 §4 の grainSize スケーリング検証。差異が残る場合はプレビューフレームの高解像度版を保存する方式に切替可能 |
| 1000 年分の表現の単調さ(版画 1500-1840・絵巻 1000-1500 の各帯) | 体験の間延び | 主観評価 | hatchScale による線密度変化・顔料退色の漸増は 03 §2.1 で対応済み。不足ならキーフレーム追加とスケール配分(04 §2.1)の再調整 |

## 6. スコープ外(明記)

- 位置情報連動(その場所の昔の写真表示など)/ AR 合成
- ギャラリー・編集機能(OS 標準に委ねる)
- リアルタイムの建物・人物の形状変換(01 §3 のとおり原理的に不可。P3 の撮影後変換で代替)
- iPad / タブレット最適化(動作はするが専用レイアウトなし)
