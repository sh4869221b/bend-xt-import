# Issue #2 中間アルゴリズムレビュー

レビュー対象は `/workspace/bend-xt-import-issue-2` から読み取り専用で取得した `/tmp/issue2-algorithm-snapshot` の内容。実装チェックアウトへの変更はしていない。基点 HEAD は `bbcac8fac627ce258099f8241c577bf4e5054b11`。未コミット実装のため、対象の同一性は末尾のファイル SHA-256 で定義する。

**具体的指摘は2件。これは中間レビューであり、修正後の最終ゼロ指摘レビューではない。** 数値的なlive chargeの校正不足、実装中の総合試験・CI等は指摘として重複列挙しない。raw constructorやtrusted helperを外部から直接呼べること自体も指摘対象にしていない。

## 1. [P1] エンコードのスカラー検査が予算確認より先に実行され、失敗時のworkがcanonical widthを満たさない

対象: snapshot `core/codec.bend:146–150`、`core/scalars.bend:35–37`、`core/storage.bend:52–68`。

`encode_read` に到達する前に `Scalars.get` がArrayから値を読み、workを1だけ消費する。その後に取得済みscalarからUTF-8幅を計算し、残りの `width - 1` を要求する。これが失敗すると `EncodeBroken` を返すが、既に検査したscalarについてwork=1しか残らない。

再現はpublic APIだけを使う。work limit=7で、長さ1のScalarChunk作成（1）、U+1F600のput（1）、容量4の出力OwnedBytes作成（4）を行う。残work=1でUTF-8 encodeを呼ぶ。scalarは読み出されるが、追加3の要求に失敗し `ResourceLimit{5,7,7,3}`、next=0、produced=0となる。エンコードに費やしたworkの差分は1であり、スカラー検査の規約値4ではない。

計画書の「encode costs scalar canonical UTF-8 width on inspection」「Execute only while enough held exists」と不一致。成功ケースの総workは一致するため、成功ベクトル照合では検出できない。失敗経路で検査済み作業の過少計上が起き、事前予算拒否の保証が崩れる。これは暫定live chargeの数値問題ではない。

修正方針: scalar bodyを読む前にcanonical widthのworkを確保できる表現・APIにする。例えばScalarChunkにwidthのメタデータを一緒に保持し、put/append/codec decodeのすべてで整合性を維持する。単純な最大4の事前予約だけではASCIIに残work=1という正当なexact-limit処理を過剰拒否するので、その点を別途解決する。width=1/2/3/4それぞれで「不足なら未読・差分0」「exact-limitなら検査成功」「Pending再開は再検査しない」を試験すべき。

再現ソース: `/tmp/issue2-algorithm-snapshot/review_encode_work.bend`。
観測出力: `/tmp/issue2-algorithm-snapshot/review_encode_work.stdout.txt`（上記の7個の数値をnative実行で確認）。

## 2. [P2] SHA updateが長さ域超過をBoundsに変換し、通常の範囲違反でも実際のlogical sizeを失う

対象: snapshot `hash/sha256.bend:231–243`。

`update_range` が入力範囲判定と `length_valid` を1個のBoolにまとめ、Falseを `update_valid` の `Bounds{index,length,65536}` に渡す。その結果、失敗理由も実際のsource lengthも保存されない。

固定native再現:

1. `Bytes.new(budget,1)`、通常の `SHA.init`、`SHA.update(...,index=1,length=1)` は `Bounds{1,1,65536}`。本当のlogical boundは1なので `Bounds{1,1,1}` であるべき。戻された数値だけを見ると要求が範囲内に見える。
2. 同じ長さ1の入力で、テスト限定でstateを `high=536870911, low=4294967295, pending=63` に注入し、`index=0,length=1` を更新すると `Bounds{0,1,65536}`。入力範囲は有効で、実際にはSHAの64-bit bitlengthへの変換可能域を超えるためOverflowであるべき。

更新自体は拒否されるので誤ったdigestを計算する指摘ではない。しかし安定したErrorのvariantと数値contextを要求する契約に反し、呼び出し側が範囲エラーとアルゴリズム長さ超過を区別できない。入力範囲・SHA長域の検証を分離し、前者には実際のsize、後者にはOverflowと意味のあるbounded contextを返す必要がある。

再現ソース: `/tmp/issue2-algorithm-snapshot/review_sha_errors.bend`。
観測出力: `/tmp/issue2-algorithm-snapshot/review_sha_errors.stdout.txt`。

## 実行・静的確認の範囲

UTF-8のlead/continuation/最小値/surrogate/上限/offset繰上げ、CP1252の定義済み251文字と5穴の表、Unicode幅、codecの通常の進捗と出力full、SHAの定数・schedule・32bit modular算術・パディング・64bit長計算、および関連するBudget/Storage/Bytes/Scalarsの所有権返却を確認した。基本変換・圧縮計算に追加の明確な誤りは見つからなかった。

提示された705 codec vectors / SHA repeated-a 31件の既存成功は補助背景であり、ここで独立に再実行・認証した結果ではない。独立native実行は上記2つの最小再現に限定した。再現プログラムは観測後に終了する小さなテストであり、完全なcleanup検証やlive charge計測用ハーネスではない。

固定imageは `sha256:b448b89eed11f6ea1b172a5f1280f8ec76e3932bb52ad01b87af487584a7ac7c`。ローカルDocker socketを明示し、`DOCKER_HOST/DOCKER_CONTEXT/DOCKER_TLS/DOCKER_TLS_VERIFY/DOCKER_CERT_PATH` をunset。`--network none --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges --memory 1g --memory-swap 1g --cpus 1` を使用した。ビルドは `/opt/bun/bun-linux-x64-baseline/bun --no-env-file /opt/bend/bend2/main.ts <input> -o <output>`、実行は `+RTS --threads 1 --gpu off -RTS`。Issue #1・research・compilerは変更していない。

両再現の最終ビルドとnative実行はexit 0。再現ソース・実行ファイル・出力のhashを `/tmp/issue2-algorithm-snapshot/repro-results.json` に保存した。

## 並行更新との区別

`/tmp/issue2-algorithm-snapshot/concurrent-comparison.txt` に各対象のsnapshot/current比較を保存した。2026-11-06T23:35:37Z比較時点では `core/codec.bend`、`core/scalars.bend`、`hash/sha256.bend` がsnapshotから変更されている。親へ指摘を先行共有し、SHAのOverflow分離やScalarChunk表現変更が進行していることは承知しているが、これらの修正版は本レポートのレビュー・再現対象ではない。修正完了・型検査・失敗経路試験・最終レビューで別途閉じる必要がある。

## 固定対象のSHA-256

完全なmanifestは `/tmp/issue2-algorithm-snapshot/SHA256SUMS`。

```text
5de49ed1d905528c08b04291919913c600d02e629a8eaf755e4ce1fa028974ba  core/budget.bend
9f36b420a86c79f04b5a6646a0b0459c8d96968a4dd0a9ea823f6bb30aecabef  core/bytes.bend
cde05faeabb60c4b3c23aca076aa7a8a41c7afc1b674d5c6abe0a409ab60da0c  core/checked.bend
9c90453230c140208cc172604ffae23dd45323b72811d7bb78d7e8ab3dcfa852  core/codec.bend
e2aad8856e1ebf4407f7cc0f6684245da1d57f2d042ff362a85e3b8c145a3c63  core/cp1252.bend
18ba2f9c55534b3a90fa53b90cadcb5c55ffa84b544d2ee9573195e42e11d582  core/cursor.bend
a9b729b4b0386f66e8ead1ab1f2734162c1a8706fc76fe7d6b035902e5452e9f  core/error.bend
c4622031b273282174b6b8c8214997ac0e639d9719873918063655add517324f  core/scalars.bend
8d591cfd62b9953596dbab4549450bea439c62ea3bb96c2618fea9166695e56b  core/storage.bend
0477cf7f9852a0bc3285f34cd98ba877e8ce568ae106b11f43af5b69820ce63d  core/unicode.bend
c83c428117457f9b0a71ba86607c7770793edb09331ec4d2bb531c4c46df3c54  core/utf8.bend
e2359eb59d9340acc2fe49b5173c87eafa3a70e6f97a5e9ad6640a65183b6244  hash/sha256.bend
367fa661617ad7b0ed268495713b3747c91d0664684a520851bc3333f60eeba6  docs/implementation/issue-2-3-plan.md
```
