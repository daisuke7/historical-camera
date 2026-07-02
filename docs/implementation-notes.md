# 実装メモ(ドキュメント凍結中の逸脱記録)

P0 実装中に発見した「設計ドキュメントとの差分・曖昧さ・実機での想定外」を追記式で記録する
(運用ルールは 08 §6)。**設計ドキュメント本体は P0 完了まで改訂しない。**
P0 完了後、ここの記録をまとめてドキュメントへ反映する。

記録フォーマット:

```
## <連番>. <YYYY-MM-DD> [T<タスク番号>] <一言サマリ>
- 該当箇所: <ドキュメント名 §セクション>
- 事象: <ドキュメントの記載と実際に起きたこと/曖昧だった点>
- 実装での扱い: <どう実装したか。ドキュメントとの差分>
- P0 後の反映案: <ドキュメントをどう直すべきか>
```

---

## 1. 2026-07-02 [T4] permission_handler(iOS/SwiftPM)はマニフェスト評価キャッシュに注意

- 該当箇所: 02 §5.1(permission_handler 採用)、05 §5(Info.plist キー)
- 事象: permission_handler_apple 9.4.10(SwiftPM 統合)は Package.swift のマニフェスト評価時に
  アプリの Info.plist を読み、`NSCameraUsageDescription` が無いとカメラハンドラを
  コンパイル対象から外す(request が即 denied を返し、ダイアログが出ない)。
  評価結果は `~/Library/Developer/Xcode/DerivedData` と
  `~/Library/Caches/org.swift.swiftpm/manifests` にキャッシュされるため、
  **キー追加前に一度でもビルドした環境では、キーを追加しても denied のまま**になる。
- 実装での扱い: Info.plist に利用目的キーを追加(05 §5 どおり)+ 上記 2 キャッシュを削除して
  再ビルドで解消。キー追加後に初めて評価される環境(新規クローン・CI)では発生しない。
- P0 後の反映案: 05 §5 に「permission_handler のカメラハンドラ有効化は Info.plist キーの
  存在に依存する。キーより後からビルド環境に入った場合は DerivedData と
  ~/Library/Caches/org.swift.swiftpm/manifests の削除が必要」の注記を追加。
