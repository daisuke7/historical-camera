# historical_camera

年代遡りカメラ「Historical Camera」の Flutter アプリ本体。

プロジェクト全体の説明・開発環境(Flutter バージョン固定、fvm、署名設定)・
実装状況はリポジトリルートの [README.md](../README.md) を参照。
設計ドキュメントは [docs/design.md](../docs/design.md) から。

- ビルド・テストは常に `fvm flutter` / `fvm dart` を使う(バージョン固定 — ルート README)
- iOS ビルドには `ios/Flutter/Local.xcconfig`(署名 Team ID。gitignore 済み)が必要
