# Issue #2 契約追加・独立計画レビュー

**結論: 追加設計に新たな必須指摘なし。** 承認済み revision 2 と併せて読む限り、今回の3つの具体化は中間レビューの原因に対応し、既承認の所有権・予算・スコープ制約と整合する。実装をこの設計で進めてよい。これは計画追加のレビューであり、修正後コードの最終受入、既存コード指摘の実証的なクローズ、Issue #2 完了の判定ではない。

対象は `/workspace/bend-xt-import-issue-2` の未コミット作業中ファイル。HEAD は `bbcac8fac627ce258099f8241c577bf4e5054b11`。読み取った内容を `/tmp/issue2-addendum-review-snapshot` に固定し、末尾の SHA-256 で対象を識別した。保存直前の比較では対象8ファイルは snapshot と同一だった。

## 指摘と追加設計の対応

| 中間レビュー | 設計上の判定 | 理由 |
|---|---|---|
| code-01 R1: zero-live 精算後の未課金 Allocation | 解決方針は妥当 | `Maybe<Allocation>` とし、actual.live=0 では None として ticket metadata を解放する。positive-live の場合のみ metadata を含む owner を返す。失敗時の ticket と budget 保持も維持するため、生存する no-op owner の課金だけを消す経路がなくなる。 |
| code-01 R2: allocation identity と logical source identity の混同 | 解決方針は妥当 | run/id/totalSize を持つ別の affine SourceOwner と、その token・buffer・base を所有する ByteWindow を導入する。root range は token の totalSize で制限し、bind は減算前に base を検査する。別 source への物理バッファ再利用は新 token を要求するため、旧 ReadState の identity を通せない。 |
| code-02 指摘1: scalar 検査後の不足課金 | 解決方針は妥当 | canonical width を別の bounded metadata 配列に保持し、値本体を読む前に正確な幅を課金する。ASCII を一律4で過剰拒否せず、幅2/3/4の不足時に値を先読みする必要もない。Pending は既検査値を保持し、output-full 再開で再検査しない。 |
| code-02 指摘2: SHA Bounds/Overflow と numeric context | 既承認契約内の実装修正として扱う | revision 2 は既に安定した Error variant/context と SHA 長さ域の checked rejection を要求している。追加設計に専用節がないことを新たな設計欠陥とはしない。一方、本レビューは SHA 修正コードを受入確認しておらず、この指摘をクローズしない。 |

SourceOwner の追加は、allocation ID の意味を変更して既存 buffer ownership に依存させるものではなく、論理ソースを別の生存オブジェクトとして扱う具体化である。same-source refill の正しさは trusted adapter の責務であることも明示されている。#2 では synthetic tests のみ、#3 で verified snapshot adapter が実データを供給するという境界は、純粋 core と OS 境界の既承認の分離と一致する。

bind/unbind、unchecked helper、raw constructor を通常 API から除外する設計は、revision 2 が採用した「言語の module privacy を保証とせず、文書・repository lint・tests で supported API を制限する」前提と整合する。ただしこの結論は、作成中の lint が既に境界を検証済みであることを意味しない。addendum の “covered by ... lint” / “rejected by ... lint” は要求する最終契約として読んだ。

width metadata の参照を bookkeeping として扱うことは、work を CPU 命令数や全物理アクセス数ではなく論理 byte visits と定義した revision 2 と矛盾しない。metadata は payload ではなく不変条件の一部であり、new・put・append・decode の全経路で値と同期させ、clear 後は logical length 外を読ませない設計になっている。追加配列の live cost と実際の性能コストを別途計測対象に含めているため、無償の物理表現を導入した扱いにもならない。

## 実装受入に残る確認事項

以下は既承認計画と中間指摘から継続するゲートであり、今回新たに発見した必須設計指摘ではない。

- zero request/cancel、live=0 かつ consumable>0、positive-live の各精算で used/held/owner の状態を確認する。positive owner の release 前後の finish と、失敗時 ticket 返却を検証する。
- 同一物理 buffer を別 source に再利用した際の旧 Range/ReadState 拒否、同一 source の幅1/2/4 cross-window 読み、totalSize/base/length の端点・overflow 拒否を検証する。消費済み prefix を再読・再課金しないことと、SourceOwner/ByteWindow の成功・失敗時 disposal を確認する。
- scalar width=1/2/3/4 について、不足時は本体未読・検査 work 差分0、exact-limit で検査可能、Pending 再開で検査課金が重複しないことを確認する。value/width の全更新経路と容量端点の整合性も必要である。
- API lint の実装と禁止利用の負例を完成させる。constructor だけでなく unwrap/rebind、unchecked/precharged helper、通常 client による buffer 抽出・変更などの迂回経路も、承認済み trusted boundary に従って検査する。
- 新しい2配列 ScalarChunk と SourceOwner/ByteWindow を含む concrete representation の生成C、重複生存・transient/error paths、計測値に基づく charge profile を確認する。暫定定数をそのまま測定済み ceiling と扱わない。
- SHA の range error は実際の logical size、bitlength 超過は Overflow と適切な bounded context を返す修正を別途検証する。
- 固定 toolchain の型検査、所有権負例と正例、本試験、測定、最終 exact-head 独立コードレビューおよび CI を完了する。

予算定数は暫定で測定ゲート未完、API lint は作成中、総合試験・CI も未完である。本レビューでは compile/native 実行や計測を行っておらず、過去の中間レビューにある再現実行を今回再実行した証拠として扱っていない。#3、file IO、production CLI、transactional apply の利用可能性も認定しない。

## 調査と変更範囲

指定された計画・追加設計・2件の中間レビューを読んだ。補助的に `core/scalars.bend`、`core/cursor.bend`、`core/budget.bend`、`core/codec.bend` を参照し、記述された表現と preflight/settlement/window 経路の具体形を確認した。対象コードを網羅的に受入レビューしたものではない。

対象 checkout とその祖先に適用される AGENTS.md、checkout 内の AGENTS.md / SKILL.md は見つからなかった。`/workspace/research/bend/AGENTS.md` は読み、upstream の言語・compiler/runtime を編集しない制約を確認した。管理環境の `cloud-environment-runtime` skill (`skill://plugin_connector_1p_c5b7d5df5d7081918f2c4be5a633ed5d/cloud-environment-runtime/SKILL.md`) を読み、environment_status を確認した。ネットワークや Docker は使用していない。

実装 checkout、Issue #1、upstream は変更していない。書き込みは読み取り snapshot と本レビュー結果ファイルのみ。承認待ち・拒否された操作はない。

## 参照ファイルの SHA-256

パスは注記がない限り `/workspace/bend-xt-import-issue-2` 相対。

| ファイル | SHA-256 |
|---|---|
| `docs/implementation/issue-2-3-plan.md` | `367fa661617ad7b0ed268495713b3747c91d0664684a520851bc3333f60eeba6` |
| `docs/implementation/issue-2-contract-addendum.md` | `f9a67140325578907ecf82a23addadb86c54cf9ee2f3ea34ddf1353b495c902c` |
| `docs/reviews/issue-2/code-01-core-contract.md` | `51307db121330fcbad62707f2bc484ddbdd3b50893ef6db04280c8924aeb253f` |
| `docs/reviews/issue-2/code-02-algorithms.md` | `88acb5ca005514aebff138fc9cfa19b1feaf6ee5afe1ba333f64ec936e35ed96` |
| `core/scalars.bend` | `7720b68279b331dbfa5a5a6a43214346dc4237accd6ec1112f40a9b431934333` |
| `core/cursor.bend` | `1d4685cd14295eea98e55580c43bf863a3abb8f4165483e83e3b11d4ab66caa5` |
| `core/budget.bend` | `5de49ed1d905528c08b04291919913c600d02e629a8eaf755e4ce1fa028974ba` |
| `core/codec.bend` | `e6271ff0da54aed2550b6ce03ec1b89c57a68a1fef6fbac88a835681513c45b7` |
| `/workspace/research/bend/AGENTS.md` | `03d9aa81c2add171a6ea5527e6aee19f2d245254d741a6ac1493e7528138c413` |
