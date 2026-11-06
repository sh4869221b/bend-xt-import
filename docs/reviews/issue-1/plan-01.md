# Issue #1 実装計画・独立レビュー 01

- 日付: 2026-11-06
- Reviewer: 独立レビュー agent `/root/issue1_plan_review_1`
- Model/role: Astra（親から依頼された独立レビュー担当）
- 入力: `docs/implementation/issue-1-plan.md`
- 入力 SHA-256: `81b2d5e7ac18c192a8cff7c9abd0cf54541c297c498f708a1c67b2c83c997b62`
- 基準 commit: `5b4643c6714e025bc248fbdbe711d54f747d8fc6`
- DESIGN.md SHA-256: `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386`
- 要件: [GitHub Issue #1](https://github.com/sh4869221b/bend-xt-import/issues/1) の本文を今回のレビューで直接取得して確認。

## 結論と findings

**今回調査した計画の範囲では、修正を必須とする actionable findings はなし。** この入力hashの計画を実装へ進めてよいと判断する。これは計画の整合性・検証方法についての判断であり、Bendの動作、メモリ予算内の成立、CI成功、Linux/WSL対応、Issue完了を認定するものではない。

重大度付きの欠陥、具体的な失敗例、修正要求として報告すべき項目は見つからなかった。以下の未確定事項は、計画自身が実装・実験で解決すると明記しているものであり、実測していないことを理由に計画欠陥へ付け替えてはいない。

## 確認した要件と判断根拠

| 観点 | 判断 |
| --- | --- |
| Issueとの対応・粒度 | U1–U6とP01–P10は固定環境、取得/build/run、binary IO、argv/exit、U32、所有権、chunk、SHAに必要な演算、resource測定・故障観測を覆う。正式parser/importer/SHA/filesystem substrateを追加しない境界が明確。API不足を記録することも検証成果として扱っている。 |
| 依存固定 | full Bend SHA、source archive digest、Bun/Clang/userland/runtime dependencies、license、Action SHAを分けて固定する。exact host pinsをU1の実装作業とするのは妥当で、未選定の配布物を検証済みと呼んでいない。binaryのbit-for-bit再現性と同一probe結果も区別している。 |
| 実Bendとoracle | 演算・変換・IOはBendが実行し、Pythonはfixtureと独立期待値、Cは試験用注入に限定される。ownership負例には失敗原因の対照、Arrayにはcapacity/valid length、算術にはwrap用途とchecked用途の区別がある。 |
| 故障注入の成立 | upstreamのread/pread/write/pwrite/close/malloc経路に対応したtest-only interposerまたはlinker wrapを選ぶ計画で、trace不在を注入成功としない。partial-read後EIO喪失、close戻り値破棄、zero-progress writeを別々に扱う。allocation NULL、mapping失敗、cgroup OOM、外部signalを混同しない。 |
| live量・work・測定 | logical bytes、live charge、retained memory、RSS、仮想アドレス、cgroup charge、workを区別する。複数bufferと変換一時領域、reserve前検査、実charge境界、長期stream plateauがある。RSS差や小さな成功例だけから一般的上限を保証しない。 |
| 独立したOS制限 | 対象だけの専用cgroup、監督側を外に置く構成、exec前の所属、limit readback、OOM events、子孫回収を要求する。共有親limitの変更、無隔離stress、1GiB RLIMIT_ASへの置換を禁じる。 |
| CI・環境不足 | 小規模suiteとfull resource gate、failure時のログ、required resource実験のunsupported/failed、WSLの独立evidenceを区別する。環境不足やskipを成功へ変換しない。CIの具体的host選定はU1/U6で残っている。 |
| 公開と範囲 | scratch以外の出力経路・製品publication処理を持たせず、突然死でも成功resultを残さない構成を検証する。公開コードがないことの確認をproduction atomic publicationの証明にしない。追加primitiveは要件として後続へ引き継ぐ。 |

## 1 GiB ceilingの解釈

DESIGN §4は実測RSSの報告と独立したprocess-memory ceilingを要求するが、全瞬間のRSSに対する数学的な上界やRLIMIT_ASを指定していない。専用cgroupの`memory.max=1073741824`と`memory.swap.max=0`を、実証済みhost profileのkernel charged-memory制限として具体化する計画は、この範囲で妥当と判断する。

cgroupのhard limitでも一時的超過があり、RSSとchargeは同じ指標ではない。この点を計画§6が明示していることを確認した。[Linux cgroup v2公式仕様](https://docs.kernel.org/admin-guide/cgroup-v2.html) のmemory.max、memory.swap.max、process所属の説明と整合する。したがって厳密RSS capを既達成扱いする修正は不要であり、実装結果にも現在の区別を維持する必要がある。

## 未確定の実装・実行事項（findingsではない）

1. Bun/Clang/libc/image等の実在artifactとexact pins、固定Bendのcheck/native build/run。静的APIの存在だけでは完了しない。
2. 注入の決定的対象選択、注入trace、実際のexit/signal、Array等のcharge式、256MiB付近の実測、長期streamでのretention。いずれもこのレビューでは実行していない。
3. 実際に1GiB制限を設定できる安全な実行経路。read-only cgroup mountと共有親16GiBは成立証拠ではなく、共有親を変更してよい根拠にもならない。
4. レビュー終盤に親担当から、管理されたlocal Docker daemonがcgroup v2で利用可能というread-only観測を受領した。これは私自身が検証した結果ではなく、containerの専用limitを設定・実証した証拠でもない。ro mountだけからDocker経路まで不成立と断定する必要はない。計画の専用隔離・readback・exec前所属・監督側分離を満たす実施候補としてU5で評価でき、採用前に成功扱いしない。計画の検証契約を変更する必須修正とは判断しなかった。
5. Linuxのresource-capable CIとWSLのLinux filesystem上の実測evidence。未実施なら対応表に未検証を残し、該当受入条件は未達とする。これらの不足は影響する実験・完了判定を止める理由であり、独立して可能なU1/U2の作業すべてを止める理由ではない。

## 調査範囲・限界

計画全文、DESIGN.md、DESIGN_REVIEW.md、GitHub Issue #1を読み、基準commitと入力hashを確認した。固定upstream checkout `/workspace/research/bend` のHEADが `266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae` であることを確認し、以下を静的に照合した。

- `bend2/base.bend`: File/byte IO、offset/size、Array.new/get/set/swap/to_listの契約。
- `bend2/effs/file_read.c`, `file_write.c`, `file_close.c`: short IO、EINTR、部分読了後error、無進捗write、closeの結果処理、read buffer確保。
- `bend2/main.ts`: VERSION、check/build経路、Clang選択、native compiler flags。
- `bend2/comp.ts`: io_mem、pool/stack/corpusの仮想mapping、runtime argv処理、threads/GPU options。
- upstream LICENSE冒頭のApache-2.0表示、およびLinux cgroup v2公式仕様。

今回のレビューは新規の独立した計画レビューであり、過去のレビュー結論を合否根拠にしていない。`/workspace/fallout-xml-bend` は参照・再利用していない。compilerの実行、故障注入、allocation/stress、cgroup/container設定変更、CI/WSL実行、外部書込は行っていない。計画本体は変更せず、本レビュー記録のみ追加した。
