# bend-xt-import

Fallout 4 MOD への xTranslator XML 翻訳インポートを、Bend で実装するための設計・検証リポジトリです。

- [設計](DESIGN.md)と[設計レビュー](DESIGN_REVIEW.md)
- [Issue #1 の実行基盤・実験手順](docs/runtime/README.md)
- [確認済みの能力と不足](docs/runtime/capabilities.md)
- [実装計画](docs/implementation/issue-1-plan.md)と[レビュー記録](docs/reviews/issue-1/)

現在のコードは runtime の実験用です。翻訳 importer、MOD/XML parser、製品用 publish はまだありません。初期の必須実行対象は Linux ネイティブです。WSL/WSL2 は利用の前提や受入必須条件ではなく、追加要望時に別途検証する範囲です。既存の Linux x86_64 実測と、未検証の WSL・実ゲームを区別して記録しています。
