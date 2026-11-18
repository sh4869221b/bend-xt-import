# bend-xt-import

Fallout 4 MOD への xTranslator XML 翻訳インポートを、Bend で実装するための設計・検証リポジトリです。

- [設計](DESIGN.md)と[設計レビュー](DESIGN_REVIEW.md)
- [Issue #1 の実行基盤・実験手順](docs/runtime/README.md)
- [確認済みの能力と不足](docs/runtime/capabilities.md)
- [Issue #1 の実装計画](docs/implementation/issue-1-plan.md)と[レビュー記録](docs/reviews/issue-1/)
- [Issue #2 の共通コア API](docs/core/api.md)、[資源測定・再実行手順](docs/core/charges.md)、[レビュー記録](docs/reviews/issue-2/status.md)
- [Issue #4 の FO4 構造解析・無変更コピー API](docs/plugin/api.md)、[検証手順](docs/plugin/validation.md)、[レビュー記録](docs/reviews/issue-4/)
- [Issue #5 の純粋 XML API](docs/xml/api.md)、[検証手順・未完の受入条件](docs/xml/validation.md)、[レビュー記録](docs/reviews/issue-5/)
- [Issue #2 / #3 の実装計画](docs/implementation/issue-2-3-plan.md)

現在のコードは、境界検査付きバイト処理・文字コード・ハッシュの共通コアと、runtime の実験コードを含みます。FO4 MOD の純粋な構造解析と無変更コピーを追加しました。純粋な xTranslator XML parser も追加していますが、固定 producer の実 export による受入条件は未完です。翻訳 importer、圧縮本文の検証・編集、製品用 publish はまだありません。初期の必須実行対象は Linux ネイティブです。WSL/WSL2 は利用の前提や受入必須条件ではなく、追加要望時に別途検証する範囲です。既存の Linux x86_64 実測と、未検証の WSL・実ゲームを区別して記録しています。
