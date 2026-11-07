# Issue #2 基礎契約・中間独立レビュー

対象: `issue-2-core`、base `bbcac8fac627ce258099f8241c577bf4e5054b11`。レビュー対象は作業中ファイルを `/tmp/issue2-core-review-snapshot` にコピーしたスナップショットです。以下の行番号と指摘は末尾の SHA-256 の内容にのみ対応します。並行作業の修正後ファイルに対する指摘や、最終レビューの結論ではありません。

結論: **修正が必要な契約上の指摘 2 件**。元の対象コード、Issue #1 worktree、`/workspace/research/bend` は変更していません。再現コードと生成バイナリは `/tmp/issue2-core-review-snapshot` にだけ保存しました。

## R1 — P1: zero-live 精算が課金を解放した後も Allocation owner を返す

位置: `core/budget.bend:109–128`、`155–163`。

`settle_valid` は `actual.live == 0` なら `retained` によって actual の live を 0 にします。しかし `settle_commit` は無条件に `Live{run,serial,get_live(actual)}` を構築し、返しています。元の Reservation 用に確保した 4096 は held から全て除去され、代わりの Allocation トークンには live 課金がありません。`cancel` も同じ経路です。

公開 API だけによる再現:

1. `start(1, Six{0,0,0,0,69632,0})`。
2. `reserve_many(budget, zero())` で 4096 を held に確保。
3. `cancel(budget,ticket)` が `Allocation` を返す。
4. その Allocation を保持したまま `finish(budget)` が成功する。
5. 成功後の分岐でも `identity(allocation)` を呼べて、serial=1 を得る。

この経路を繰り返すと、未課金の affine owner が保持可能です。affinity は二重使用を防ぎますが、トークンの生存量を制限しません。暫定 charge の数値の大小ではなく、保持している表現の課金がゼロに落ちる lifecycle の問題です。`allocate(budget,0,...)` は 4096 を保持するため、そちらとも不整合です。

**修正:** 精算成功値を `Maybe<&1, Allocation>` 等に変更し、actual.live=0 は `None`、positive はメタデータ charge を含む `Some{allocation}` にする。`cancel` で no-op allocation を作らない。失敗時の Reservation 返却は維持する。この方針は実装側と共有済みですが、この報告では修正後を未検証です。

**回帰確認:** zero request/cancel と live=0・consumable>0 の精算は None で used/held が正しいこと。live>0 は owner を返し、release 前の finish が失敗し、release 後に成功すること。失敗時は ticket と counters が保持されること。

**実行証拠:** `/tmp/issue2-core-review-snapshot/repros/zero-live.bend`。固定 image `sha256:b448b89eed11f6ea1b172a5f1280f8ec76e3932bb52ad01b87af487584a7ac7c` の Bend 2.0.40 C backend でコンパイル成功、生成 binary 実行 exit=0、stdout=`1`。これは finish 成功後にも Allocation identity を取得できた結果です。既存の `tests/core/budget.bend` は positive-live 精算・release のみで、この経路を通りません。

## R2 — P1: バッファの allocation identity を論理ソースの identity に兼用している

位置: `core/storage.bend:10–18,90–92`、`core/bytes.bend:48–61`、`core/cursor.bend:27–28,163–173`。

Storage の origin は Allocation.serial で、`clear`・`put`・`append` を経ても同じです。`continued` がチェックするのはその run/origin と ReadState 内の run/origin の一致だけです。読み込み窓の base は外部から U32 として渡され、論理ソースとの関連は型にもチェックにもありません。

したがって通常 API で次の状態遷移が可能です:

1. あるバッファへ source A の先頭2バイトを格納し、その run/origin で4バイト Range を作り、幅4の ReadState を開始する。
2. `continued(...,base=0,...)` が2バイトを消費して NeedMore を返す。
3. 同じ OwnedBytes を `clear` し、別 source B の2バイトを append する。
4. 旧 ReadState と `base=2` を `continued` へ渡す。
5. identity 検査を通り、A の prefix と B の suffix を結合して ReadDone になる。

これは未検証 raw constructor の利用を必要としません。必要な窓の補充と別ソースへのバッファ再利用を現 API が区別できないため、計画の「別ソースの range/cursor を拒否する」契約を allocation ID だけでは実現できません。上記はソースからの静的遷移確認であり、独立した native 再現は実行していません。

**修正:** バッファの所有権とは別に、immutable な run/source-id/totalSize を持つ affine SourceOwner を mint し、ReadState/Range をその identity に束縛する。Window は SourceOwner・OwnedBytes・absoluteBase を所有し、読みは Window を thread する。通常利用側から Window 内の Bytes を put/clear できないようにする。refill は trusted adapter だけが同じ論理ソースとの対応を確認して再 bind し、別 source への再利用では新 SourceOwner を使う。この方針は実装側から提示され、妥当と判断しました。

この修正に必要な追加条件:

- root Range は caller-supplied `size` ではなく SourceOwner.totalSize へ検証する。
- Window bind で `base <= totalSize` と `length <= totalSize - base` を検査し、absolute endpoint の overflow と source 範囲外を拒否する。
- unwrap/rebind およびチェックを省略する helper も trusted adapter の allowlist 対象にする。raw constructor だけを禁止しても安全な公開 API 境界にはならない。
- 旧 source の Range/ReadState を、同じ物理バッファの別 source への再利用後に渡す負例を追加する。正当な同一 source の複数窓での幅1/2/4読みは成功し、消費済み prefix を再課金・再読しないことも確認する。

## 確認した範囲と留保

`error` の bounded numeric context、checked add/sub/mul と capacity の有限深さ、正規 API で作った Storage に対する index/length/capacity 検査、Range/subrange/take の加算前の減算ベース検査、Budget の正規 ticket に対する used/held の preflight と failure ownership return には、このスナップショットで追加の具体的欠陥は確認していません。これは全面的な健全性証明ではありません。

一つの invocation に一つの affine Budget、trusted core 外で raw constructor/unsafe helper を使わせない境界、charge 定数は実測前の暫定値、という前提を尊重しました。偽造 Budget/Allocation、二つの同じ run の Budget、暫定 charge の未校正を独立した欠陥として数えていません。UTF-8/CP1252/SHA、校正、本試験、CI の作業中部分の未完成は今回の指摘対象ではありません。

AGENTS.md は対象 checkout および /workspace の祖先にありませんでした。参照先 `/workspace/research/bend/AGENTS.md` は読み、compiler/lang/runtime を変更していません。管理環境の cloud-environment-runtime スキルと Docker 実行指示を確認しました。Docker は local socket・network none・UID 1000・cap-drop ALL・1GiB memory/swap・1 CPU、生成 binary は `+RTS --threads 1 --gpu off -RTS` で実行しました。

今回の実行は最小再現1件であり、本試験や校正の代替ではありません。修正後の再レビューと、最終 exact-head の独立ゼロ指摘レビューが必要です。

## 読み取ったファイルの SHA-256

| ファイル | SHA-256 |
|---|---|
| `docs/implementation/issue-2-3-plan.md` | `367fa661617ad7b0ed268495713b3747c91d0664684a520851bc3333f60eeba6` |
| `core/error.bend` | `a9b729b4b0386f66e8ead1ab1f2734162c1a8706fc76fe7d6b035902e5452e9f` |
| `core/checked.bend` | `cde05faeabb60c4b3c23aca076aa7a8a41c7afc1b674d5c6abe0a409ab60da0c` |
| `core/budget.bend` | `d73c1383b58826ab6429df302110f024c5cc2a1ce1556ac7f730a567414dc874` |
| `core/storage.bend` | `8d591cfd62b9953596dbab4549450bea439c62ea3bb96c2618fea9166695e56b` |
| `core/bytes.bend` | `9f36b420a86c79f04b5a6646a0b0459c8d96968a4dd0a9ea823f6bb30aecabef` |
| `core/scalars.bend` | `c4622031b273282174b6b8c8214997ac0e639d9719873918063655add517324f` |
| `core/cursor.bend` | `686e8b646d84c3756ed7d96fe334652c18ca93464158adb1934a88b37bfb2a9a` |
| `core/unicode.bend` | `0477cf7f9852a0bc3285f34cd98ba877e8ce568ae106b11f43af5b69820ce63d` |
| `tests/core/budget.bend` | `2ea1f198850f3883f7df5bd510d3441314f31f13b0e5bf6a756624958945139b` |
| `tests/core/foundation.bend` | `5c6db76a3da645f68695fb08545229a4daaf13e592508af96b3b1feb52d4248f` |

## 報告保存時の作業中ファイルとの差分

以下は snapshot 後に内容が変わりました。この報告の指摘を修正後に適用済みとは扱いません。

- `core/budget.bend`: 現在の SHA-256 `5de49ed1d905528c08b04291919913c600d02e629a8eaf755e4ce1fa028974ba`
- `tests/core/budget.bend`: 現在の SHA-256 `becb7633765e1f29483180e6b2a87d8d85dd08beb66669f8d1ec593ae971bfe6`
- `tests/core/foundation.bend`: 現在の SHA-256 `c4ee233ed18506c178c449a76be804f14e6e84271b995417d52d251408f61cfa`

## 再現物の SHA-256

- `/tmp/issue2-core-review-snapshot/repros/zero-live.bend`: `b8ece8e2764531d3c84a2fcb149adecbc8218ea387b82bee56570c4bbf8923f3`
- `/tmp/issue2-core-review-snapshot/build/zero-live`: `a76c79a2e78f6397bba4778e947ccb30ba95a24adf88b8296247fbc853fa08e0`
