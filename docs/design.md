# 年代遡りカメラアプリ「Historical Camera」設計ドキュメント

カメラプレビューに「年代フィルター」を掛け、スライダーで過去(最大西暦1000年)まで遡った見た目を
リアルタイムに再現するモバイルアプリの設計ドキュメント一式。

- 開発: Flutter (UI・ロジック) + ネイティブ Swift / Kotlin (カメラ・フィルタパイプライン)
- ビルド環境: Android Studio (Flutter 開発・Android ビルド) / Xcode (iOS ビルドツールチェーン)
- 対象 OS: iOS 15+ / Android 8.0 (API 26)+

## ドキュメント構成(読む順・実装する順)

| # | ファイル | 内容 |
|---|---------|------|
| 1 | [01-feasibility.md](01-feasibility.md) | 実現可能性の考察。技術選定の根拠。**最初に必ず読むこと** |
| 2 | [02-architecture.md](02-architecture.md) | 全体アーキテクチャ、レイヤー分割、Platform Channel API 完全仕様 |
| 3 | [03-era-filter-spec.md](03-era-filter-spec.md) | 年代フィルターの仕様。年代→エフェクトパラメータ対応表、補間アルゴリズム、シェーダー仕様 |
| 4 | [04-ui-spec.md](04-ui-spec.md) | 画面レイアウト(縦・横)、スライダー仕様、状態遷移 |
| 5 | [05-ios-implementation.md](05-ios-implementation.md) | iOS ネイティブ層 (Swift) の実装詳細 |
| 6 | [06-android-implementation.md](06-android-implementation.md) | Android ネイティブ層 (Kotlin) の実装詳細 |
| 7 | [07-recording-feasibility.md](07-recording-feasibility.md) | 録画機能の実現可能性検討と設計(フェーズ2) |
| 8 | [08-implementation-plan.md](08-implementation-plan.md) | 実装フェーズ、ファイル一覧、タスク分解、受け入れ基準 |

## LLM に実装させる場合の使い方

1. 常に `02-architecture.md` をコンテキストに含める(インターフェース定義の単一情報源)。
2. タスクは `08-implementation-plan.md` のタスク分解単位で 1 つずつ与える。
3. Dart 側のタスクには `03` `04` を、iOS タスクには `05` を、Android タスクには `06` を添付する。
4. インターフェース(channel 名・メソッド名・パラメータ名)はドキュメントの記載を正とし、変更しないこと。

## 用語

| 用語 | 意味 |
|------|------|
| 年代 (era) | スライダーで選択された西暦年。10 年単位に量子化される |
| FilterParams | 年代から算出される 20 個のエフェクトパラメータの構造体(02 §2 で確定。増減は 02 の改訂を伴う場合のみ)。Dart で算出しネイティブに送る |
| プレビューパイプライン | カメラ→フィルタ→Flutter Texture の毎フレーム処理経路(ネイティブ実装) |
| 写真パイプライン | 静止画キャプチャ→フル解像度フィルタ適用→保存の経路(ネイティブ実装) |
