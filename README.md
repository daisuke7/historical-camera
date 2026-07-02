# Historical Camera — 設計・実装実験プロジェクト

カメラプレビューをスライダー操作で過去(最大西暦1000年)まで遡った見た目に変える
モバイルアプリ「年代遡りカメラ」を題材にした、**設計と実装の実験プロジェクト**。

## このプロジェクトについて

単なるアプリ開発ではなく、次のプロセスを検証する実験の場である:

1. **設計フェーズ**: 実装可能性の考察を尽くし、詳細な設計ドキュメントを作成する
2. **実装フェーズ**: その設計ドキュメントを与えれば、比較的低いレベルの LLM モデルでも
   実装できるか(=設計の詳細度・自己完結性が十分か)を検証する

したがって、設計ドキュメントは「インターフェース定義の単一情報源」「タスク単位で
コンテキストに渡せる分割」など、LLM への指示書として機能することを意図して書かれている。

## アプリ概要

- 全画面カメラプレビュー + 画面下の年代スライダー(10年単位、右端=現在、左端=西暦1000年)
- スライダーを過去に動かすと、プレビューがその年代の記録メディア風に変化する
  (カラー写真 → 退色 → モノクロ → セピア → 版画 → 絵巻、と連続的に移り変わる)
- シャッターでフィルタ適用済みの写真を保存。録画モードは将来フェーズ
- 技術構成: Flutter (UI・ロジック) + ネイティブ Swift / Kotlin (カメラ・GPU フィルタ)

## リポジトリ構成

| パス | 内容 |
|------|------|
| [docs/design.md](docs/design.md) | 設計ドキュメントの索引(ここから読む) |
| docs/01〜08-*.md | 実現可能性考察・アーキテクチャ・フィルタ仕様・実装計画などの各論 |
| [docs/prompts-history.md](docs/prompts-history.md) | 本プロジェクトに投入したプロンプトの記録 |
| `historical_camera/` | Flutter アプリ本体 |

## 開発環境(バージョン固定 — docs/08 §4)

- Flutter **3.44.4**(Dart 3.12.2)。**fvm で historical_camera/ にのみ固定**(`.fvmrc`)。
  コマンドは常に `fvm flutter` / `fvm dart` を使うこと
- 採用パッケージ(docs/02 §5.1。追加時のバージョン):
  `flutter_riverpod ^3.3.2` / `freezed_annotation ^3.1.0` / `permission_handler ^12.0.3` /
  `wakelock_plus ^1.6.1` / dev: `build_runner ^2.15.0` / `freezed ^3.2.5` /
  `mocktail ^1.0.5` / `flutter_lints ^6.0.0`
- アプリ ID: **`com.daisuke7.historical.camera`**(iOS bundle id / Android applicationId・namespace で統一。Kotlin パッケージも同名)
- iOS ビルドには **Xcode の Metal Toolchain** が必要(近年の Xcode では別コンポーネント)。
  未インストールだと `.metal` のコンパイルで失敗する。インストール方法:
  `xcodebuild -downloadComponent MetalToolchain`(約 700MB)、
  または Xcode > Settings > Components から

## ライセンス

MIT License([LICENSE](LICENSE))。Copyright (c) 2026 Daisuke Sawada(daisuke7)

## ステータス

- [x] 設計フェーズ: 設計ドキュメント一式(docs/)作成済み — 2026-07-02
- [ ] 実装フェーズ: P0 進行中(docs/08-implementation-plan.md のタスク分解に従う)
  - [x] T1 Flutter プロジェクト雛形 — 2026-07-02
  - [x] T2 Dart ドメイン層(FilterParams/EraFilter/EraScale+単体テスト24件) — 2026-07-02
  - [x] T3 プラットフォーム層+状態管理(CameraEvent/NativeCameraApi/CameraNotifier+テスト25件) — 2026-07-02
  - [x] T4 Flutter UI(CameraScreen/EraSlider/EraLabel/ShutterButton+widgetテスト7件) — 2026-07-02
  - [x] T5 iOS パススルー(AVFoundation+Metal→Flutter Texture。実機で全画面プレビュー・回転・30fps確認) — 2026-07-02
  - [x] T6 iOS フィルタシェーダー(03 §3 の MSL 移植。実機検証: 年代変化・パススルーXCTest・GPU 5.3〜7.4ms@720p) — 2026-07-02
  - [x] T7 iOS 写真保存(フル解像度フィルタ適用+フォトライブラリ保存。実機検証: 見た目一致・向き・現代=無加工) — 2026-07-02
  - [x] T8 Android パススルー(CameraX+GL ES3+SurfaceProducer。Pixel 6 実機で全向き・アスペクト・UI追従確認。回転モデルの実挙動は implementation-notes #3) — 2026-07-02
  - [ ] T9〜T10 Android フィルタ/写真保存 / T11 結合
