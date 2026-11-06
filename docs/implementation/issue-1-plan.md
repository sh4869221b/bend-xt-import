# Issue #1 実装計画: 固定 Bend 2 実行基盤とリソース制限の検証

計画作成時の状態: **計画、未実装・未実行**。作成日: 2026-11-06。計画作成担当: Astra。

**実行対象の訂正（2026-11-06）:** WSL/WSL2 はユーザー指定ではなく設計側で加えた仮定だったため、以下の現行受入条件から外す。必須実行対象は Linux ネイティブとし、WSL は追加要望があった場合に独立した profile として検証する。WSL 未実測は Linux ネイティブの Issue #1 完了を妨げず、対応済みを意味するものでもない。その他の実験・安全性・予算・Gate A 条件は変更しない。Native Windows の将来対応可能性も否定しない。

下記の調査・未実施という記述と基準 hash は計画作成時点の記録である。[訂正前の計画](https://github.com/sh4869221b/bend-xt-import/blob/65422592ee603a8db17ef5d41af4c615a436fb98/docs/implementation/issue-1-plan.md)を保持し、実装後の検証結果は[能力表](../runtime/capabilities.md)と[evidence](../runtime/evidence/)を参照する。

対象は [Issue #1](https://github.com/sh4869221b/bend-xt-import/issues/1) と [DESIGN.md revision 0.4](https://github.com/sh4869221b/bend-xt-import/blob/5b4643c6714e025bc248fbdbe711d54f747d8fc6/DESIGN.md) §§2, 4, 11（計画作成時の根拠）。基準リポジトリ commit は `5b4643c6714e025bc248fbdbe711d54f747d8fc6`、DESIGN.md の SHA-256 は `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386`。Issue 本文を 2026-11-06 に GitHub から読み取った。本書の試験と受入条件は今後行う作業であり、成功結果ではない。

実装開始条件は、別の Astra による本計画の独立レビュー、指摘修正、残存する実装阻害事項の解消である。本書の追加以外にコード、CI、環境設定を変更していない。以前の未承認実装 `/workspace/fallout-xml-bend` は参照・再利用・変更・公開しない。

## 1. 完了時に得るものと範囲

この Issue の成果は、固定した compiler/host から再現できる小さな **Bend 実験群**、その runner、測定記録、および機能ごとの可否表である。正式な importer、共通 bytes ライブラリ、XML/plugin parser、codec、core hash/SHA-256 実装、production filesystem substrate は作らない。Python/C は取得・試験・計測・故障注入だけに使い、Bend の演算や変換をホスト側で代行して成功扱いしない。

本 Issue で `apply`、`publish`、`verify --bundle` 等の製品コマンドを実装しない。fixture は任意の合成 byte 列であり、MOD/XML の解析・変換はしない。成功した probe も Gate A 全体、atomic publish、game-safe、対応最大入力サイズの証拠ではない。後続の安全な filesystem 基盤が完成するまで公開能力は常に blocked とする。

Issue #1 の結果を「検証済み」「失敗を実測」「未検証/環境不足」に分ける。受入条件を満たせなかった項目を skip のまま成功とせず、具体的な capability block と追試条件を残す。単なるドキュメントの整備を、この Issue の実行検証完了とはしない。

## 2. 静的調査で得た根拠と採用 pin

### 2.1 Compiler と backend

第一候補かつ実装開始時の採用 source pin は **`bendlang/bend@266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae`**。DESIGN の参照 pin と一致し、ローカル upstream checkout `/workspace/research/bend` の HEAD・origin・clean tree を読み取り確認した。[upstream commit](https://github.com/bendlang/bend/commit/266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae) の存在も確認した。`bend2/main.ts` の VERSION は `2.0.40`、LICENSE は Apache-2.0。これらは出所とソースの根拠であり、正常動作の認証ではない。

採用経路は固定 source checkout と固定 Bun から `bend2/main.ts` を動かし、同じ checkout の `base.bend`、`comp.ts`、`effs/*.c` を使って Linux native C backend を生成する経路とする。GPU と JS backend はこの Issue の対応対象にしない。初期 profile は x86_64、CPU 1 worker。多 worker の成立は別測定が通るまで宣言しない。

既存 `/workspace/toolchains/bend-2.0.40` の実行ファイルは、名前・version 表示だけでは source pin と同一と証明できないため採用しない。再利用する場合も入手 URL、archive/binary digest、source との対応、同梱 Base/effects、build provenance を新規取得品と同様に検証する必要がある。本計画では既存 binary を実行していない。

pin を変更する必要が生じた場合は、理由、旧新 full SHA、関連 API/runtime 差分、全 probe 再実行結果を独立レビューに回す。浮動 main や別 version への無記録 fallback はしない。upstream 自体には本 Issue から変更を加えない。

### 2.2 ホスト依存を固定する実装単位 U1

以下の exact version/digest は **未選定**。U1 で実在する配布物を検証して確定し、その後の probe 結果は確定済み lock だけに結び付ける。未確定の hash を埋めたり、`latest` を lock と呼んだりしない。

| 対象 | 固定する値・選定根拠 |
| --- | --- |
| Linux userland | distribution、architecture、container image digest または snapshot package source と exact package versions。kernel は image に含まれないため別記録 |
| Bun | upstream release の exact version、platform archive URL と SHA-256、license。Bend pack の `@types/bun` version を Bun runtime version と混同しない |
| native compiler | exact Clang version/build と配布物 digest。`main.ts:cc_find` は CPU build に Clang 14 以上を要求する。gcc だけの環境は前提不足 |
| libc/headers/linker | exact packages、architecture、動的リンクされた runtime dependencies、ライセンス情報 |
| harness | Python 3、Git、download/hash/unpack tools の exact package versions。Python は stdlib のみを第一選択 |
| CI actions | 実在する Action の full commit SHA、使う場合の container digest。runner label は OS image pin の代用にしない |

`sources.lock` は machine-readable JSON とし、schema version、component role（compiler/host/reference/test-only）、origin、full revision/version、取得 URL、artifact SHA-256、license/SPDX と license file の参照、採用理由、build recipe ID を記録する。Bend source は Git full SHA に加えて取得した source archive の digest も記録する。生成 binary の digest は run/build record に記録し、同一ソースからの再ビルドと binary の bit-for-bit 再現性は別評価にする。

DESIGN の xTranslator `9aa38d60860273401f8bb0dd1557c82a295c41b3`、xEdit `9058a79437367c2cb1b757a9021ab443d743012d` は reference-only として版と実際の license file を調べて記録する。ビルド依存にしない。ライセンスが未確認なら unknown と明記し、コードのコピーをしない。Apache-2.0 のコピー/改変を行う場合には当該 upstream notices を残す。技術仕様への参照とソースの取り込みを区別する。

### 2.3 API を読んで分かった検証上の注意

以下は設計 pin の静的読解結果。実際のコンパイル・実行結果はまだない。行番号は pin に対するもの。

| 根拠 | 読み取った性質 | 計画への反映 |
| --- | --- | --- |
| `bend2/base.bend:220–244` | `IO.args`、native の raw-byte `IO.args_bytes`、`IO.exit` がある | argv[0]、runtime args 除去、空白/非 ASCII、終了コードを実測 |
| `base.bend:364–398` | byte IO は `List<U32>`、`read_at/write_at/size` は U32、`close` は `IO(Unit)` | packed byte array と仮定せず List と Array 変換のピークも測る |
| `effs/file_read.c:file_read_fill` | short read/EINTR を繰り返す。一部読了後の error は読了 bytes を返し error を隠し得る | transient error + 後続成功も注入。短い読了を無条件に EOF/全体成功にしない |
| `effs/file_write.c:file_write_fill` | short write/EINTR を繰り返し、0 progress は EIO。失敗時に prefix が残り得る | 二重書込、無限ループ、prefix 残留を外部 oracle で検出 |
| `effs/file_open.c` | mode `x` は O_CREAT/O_EXCL、通常の path open | exclusive-create と安全な namespace/publication を分離 |
| `effs/file_size.c` | UINT32_MAX より大きい file は EOVERFLOW | sparse file 境界 probe。offset+length の checked preflight を別に置く |
| `effs/file_close.c` | `close()` の戻り値を捨てる | checked-close capability は stock API では不足 |
| `base.bend:2733,2764` | `Array.new` の引数は長さでなく深さ d（2^d cells）。get は array と値を返し、添字を mask する | d=16 で 65536 cells。logical length を明示して境界前に拒否する実験 |
| `comp.ts:corpus_setup/pool_stack/pool_try` | CPU corpus は初期 8 GiB、stack は 2 GiB 等の virtual mapping。MAP_NORESERVE を使う | RSS と VmSize を別記録。RLIMIT_AS=1GiB を採用しない |
| `comp.ts:io_mem` | host allocation NULL で `host allocation failed` の fail-stop | structured resource error と決めつけず OS status/stderr を観測 |

参照: [Base](https://github.com/bendlang/bend/blob/266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae/bend2/base.bend)、[native effects](https://github.com/bendlang/bend/tree/266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae/bend2/effs)、[compiler/runtime](https://github.com/bendlang/bend/blob/266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae/bend2/comp.ts)、[CLI](https://github.com/bendlang/bend/blob/266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae/bend2/main.ts)。Base の宣言や source comment だけで pass を付けない。

## 3. 再現可能な取得・ビルド・実行 U1–U2

1. lock を読み、指定した URL/commit のみを task 専用 cache に取得する。digest/revision が違えば停止。global install や floating installer の `curl | sh` は使わない。
2. clean source tree と実際に使用する Base/effects の digest を記録する。Bun source 経路は `.env`/`bunfig.toml` を読み得るため、管理した clean directory から起動し、意図しない preload/config を拒否する。認証情報を含む environment dump は作らない。
3. `BEND_NO_TELEMETRY=1`、明示した `CC`、空の `BENDRTS`、固定 locale 等の必要な設定だけを記録する。network 取得終了後、compile/run phase がネットワークに依存しないことを確認する。proxy/CA は正規設定を使う。
4. source の CLI が実際に認識する `--check-only`、`-o <binary>`、`-o <file.c>` を使う。想像した `--compile`、`--run-c`、`--heap` 等は追加しない。まず check → native build → native 実行を分離する。
5. runtime の `+RTS --threads 1 --gpu off -RTS` は source に存在する候補であり、U2 の smoke probe で受理と効果を確認して初めて標準コマンドにする。argv probe には runtime option と同じ文字列を通常引数として渡すケースも用意する。
6. 各 run は clean な private scratch に fixtures を作り、入力・期待値 digest、compiler source digest、生成 C/binary digest、host/kernel/filesystem、実際の argv、exit/signal/stdout/stderr、時間・メモリ・work を記録する。空 log/途中終了を pass にしない。
7. clean cache からの再取得・ビルドを二度行い、同じ fixtures/probe 結果となることを確認する。binary digest が一致しない場合は path/build metadata 等の差を調査し、未達の reproducible-binary claim を避ける。

最終 runbook には placeholder のない実行済みコマンドを載せる。ビルド process のメモリは測るが、以下の 1 GiB runtime 検証とは分離する。Bun/compiler の消費を native probe の消費に混ぜない。

## 4. 実 Bend probe と独立 oracle U3

各 probe は小さく単独で build/run できる形とし、明確な expected stdout/byte output/exit を持つ。oracle と入力 generator は Python stdlib でよい。expected data は probe から生成して自己比較しない。すべて合成・非秘密 fixture とする。

| ID / 予定 probe | 検証内容・境界 | pass と失敗の扱い |
| --- | --- | --- |
| P01 `argv_exit.bend` | argv[0]、空引数、空白、ASCII/日本語、`--`、runtime delimiter。`IO.args_bytes` に非 UTF-8 pathname bytes。exit 0 と 2..7、die/error 経路 | subprocess の実 argv/status と一致。製品 exit mapping 未実装であることを明記。signal を 0 や resource code 5 に書き換えない |
| P02 `binary_roundtrip.bend` | 0..255 全値、先頭/中間/末尾 NUL、invalid UTF-8、empty、長さ 1/65535/65536/65537/131073 | byte-for-byte 一致。文字列 IO による正規化が混入したら fail |
| P03 `offsets.bend` | `read_at/write_at` の位置不変性、size、EOF、zero count、UINT32_MAX 付近。4GiB-1/4GiB の sparse files | 実読書は数 bytes に限定。file size/offset bounds と EOVERFLOW を比較。4GiB 以上は拒否、preflight に wrap なし |
| P04 `exclusive_create.bend` | 存在なし/既存 file/既存 directory/末端 symlink、同じ path の同時 x create | 新規成功は一つ、他は EEXIST 系、既存内容不変。親 symlink 等の安全性までは意味しない |
| P05 `io_errors.bend` | ENOENT、確実な EACCES（非 root 条件）、invalid mode、byte 256、read-only handle write、/dev/full または局所的 ENOSPC injection | Result の失敗を検出、期待診断/status。invalid bytes はゼロ書込。root で permission test が通ってしまう場合は未試験 |
| P06 `short_io.bend` | 下記 syscall 故障注入 matrix を実 native IO で通す | short/EINTR の正しい再試行、0 progress/hard error の停止、timeout なし、data 重複/欠落なし |
| P07 `affine_arrays.bend` | Array の get/set/swap と ownership thread、clone が必要な場合の費用、File ownership。再利用を破る negative source も check | positive 実行と negative typecheck rejection。負例は構文 typo 等の別原因で失敗していないことを対照で確認 |
| P08 `chunk_stream.bend` | 64 KiB を上限に List↔Array↔IO、最終 partial chunk の logical length、many-chunk stream | 総入力に比例して buffers を保持しない。最後を 65536 まで pad して出力しない。値を外部 oracle と比較 |
| P09 `sha_primitives.bend` | U32 wrapping add、xor/and/or/not、logical shift、rotate、big-endian pack/unpack、16/64 words buffer 更新、hi/lo bit-length carry | 固定+seeded random vectorsを外部整数 oracle と比較。shift 0/1/31/32 の意図を明示。64-bit長さの計算は二 limb。SHA-256本体やhash completionを主張しない |
| P10 `budget_work.bend` | reserve/release/work の局所的実験、overflow前拒否、同じchunkを複数pass | 下記 U4 の境界・累積条件。formal shared libraryとして公開しない |

P03 の sparse file は対応 filesystem でのみ行い、実ディスクを 4GiB 埋めない。case ごとに disk/time 上限を設ける。offset checked logic は `position <= end` を先に検査し、`size <= end-position` の後に加算する。U32 modulo 演算を必要とする SHA probe と size/work の overflow拒否を混同しない。

P07/P08 では Array capacity と valid length を別に持つ。capacity外 get/set は標準 API が failすると思い込まず、caller の range guard の前後を観測する。`Array.new(U32,16n,...)` は 65536 cells であって 65536 packed bytes ではない。List入力、Array、List出力、C IO scratch が同時に live になる局面を U4 で含める。

P06 は regular-file happy path だけでは不足する。test-only interposer/helper は read/pread/write/pwrite/close と host malloc/realloc の指定対象 fd/call にだけ作用し、trace に適用位置を残す。動的リンク状況を確認し、LD_PRELOAD が使えなければ pinned generated C に対する test-only linker wrap を検討する。どちらも未計測 binary と instrumentation binary を区別し、production effect の実装にしない。

- read/pread: 1,7,4095 bytes に分割、EINTR→成功、EOF途中、最初からEIO、一部成功→EIO、一部成功→一回EIO→後続成功。
- write/pwrite: 分割、EINTR、0 return、prefix後 ENOSPC/EIO、最初から失敗。途中で失敗した出力は scratch に残っても成功判定しない。
- close: 実 close の後に EIO を返す注入で error が Bend に届くかを測る。stock の戻り値破棄は既知 gap として結果に残し、これを checked-close pass にはしない。
- 永続的な無進捗は外部 timeout で止める。timeout は明確な fail。injection trace がなければその注入ケースは実行できていない。

部分読了後の error を stock が失う場合、既知 size までの exact-length loop だけで全 error を捕捉したとは主張しない。最終的に bytes が揃っても一時的 error の証拠が消えるケースを報告する。厳密な error 伝播には追加 read primitive が必要か、後続 substrate の契約として判断し、未解決中はその capability を blocked とする。

## 5. 実表現・live予算・work予算 U4

### 5.1 区別する量

| 指標 | 意味・測定 |
| --- | --- |
| logical input bytes | file/fixture の長さ。memory と同一視しない |
| live payload/index charge | Bend内のデータと一時変換bufferに対する、測定とlayout根拠に基づく予約量。上限 **268435456 bytes (256MiB)** |
| allocator retained/high-water | 解放後もruntimeが保持するarena/pages。live reserve返却とRSS低下は別 |
| native process peak RSS | OS の ru_maxrss（LinuxではKiB→bytes）と/proc VmHWM、補助的にsmaps_rollup。短命processの最終値も回収 |
| virtual address size | VmSize/仮想mapping。lazy予約はRSSに直接加算しない |
| cgroup charge/peak | memory.current/peak/stat。file cache/kernel等を含み、process RSSとは異なる |
| work | 実際に行う byte visits / element operations / pass数。wall time は補助指標 |

計測は ordinary native binary の結果を基準にする。instrumented allocator/layout build は原因解析専用とし、測定 overheadとbuild差を記録する。消費された配列の結果checksum等を外へ出して optimizer の消去を防ぎ、遅延pageを触った実在データで比較する。

### 5.2 実験系列と予算計算

empty IO baseline、List<U32>、Array<U32>、固定幅tuple/index候補、nested record候補、String（ASCII/日本語/非BMP）、List↔Array変換、64KiB stream を各々測る。capacity 2^k の境界前後、小～大の段階系列、同時live 1/2/3 buffers、繰返し allocate/drop（入力量がlive量を大きく上回る場合）を含める。minimum/median/maximumと3回以上の反復、host差を記録する。

sourceの `Term=u64` や U32 lower layoutだけから全オブジェクトを4/8 bytesと決めない。生成 C、allocation class、alignment、header、power-of-two capacity、boxed fields、temporary copies を追い、測定と照合する。単純なRSS差の傾きだけでは上限保証にしない。各representationについて「保守的なcharged size式 + 固定overhead + 同時live temporaries + 測定margin」と適用範囲を文書化する。根拠が不足するrepresentationは後続の利用をblockedにする。

予約実験では allocation **前**に `cost <= limit-used` を確認し、増加・resize・clone・変換の全同時live分を予約する。受け渡しで二重にreleaseせず、ownership終了後にだけlive chargeを返す。checked multiplication/additionの境界、ちょうど予算、1単位超過、release後再予約を試す。上限超過なら確保開始前にresource failureとなることをtraceで示す。

大きいカウンタ境界は synthetic request によって、巨大実allocationなしでも検証する。ただしこれと実際に256MiB charge付近まで伸ばす測定は別ケースとする。実stressはU5のOS制限の中で行う。予算いっぱいの代表workloadがOS上限を先に叩く場合は「256MiB予算内なら処理可能」と宣言せず、対応範囲・charge式・runtime overheadを再評価する。設計の数値を無断で緩和しない。

runtimeがdrop後にもmemoryをretainする場合は、一定live量の長いstreamでRSS/chargeのplateauを確認する。plateauしなければ streaming bounded-memory capabilityは未成立。1chunkが通っただけで256MiB入力や数百万indexを対応済みにしない。実format workloadは後続Issueで同じ計測を再度行う。

### 5.3 作業量

P10は実験用にbyte-visitsをrun全体で累積し、上限 **1073741824 visits** の境界を試す。read、List/Array traversal、変換、再scan、verification相当の再訪を別labelで数え、総数も持つ。logical bytes、OS read bytes、decode相当workを同じ意味の一個のcounterと呼ばない。実験はdecoderやtable parserを実装しない。

`cost <= remaining` の後に減算する方式等でU32 wrapを防ぐ。小さい設定で actual repeated traversal が枯渇するケースと、1GiB/UINT32_MAX 付近をsynthetic counter incrementで確かめるケースを分ける。pass/entry単位のreset、alias入力だから無償扱い、releaseによるwork返却をしない。SHAのbit-length counterは別で二limbを検証する。外部oracleがfixture長×実pass数等から期待workを独立計算し、instrumentationの付け忘れを検出する。

## 6. 独立した1GiB上限・allocation failure・強制終了 U5

### 6.1 採用候補と意味

第一候補は **専用cgroup v2の `memory.max=1073741824`、`memory.swap.max=0`**。probe processとその子孫だけを入れ、監督harness/compilerは外に置く。対象はnative実行中のkernel charged memoryであり、**正確な per-process RSS cap でも virtual-address cap でもない**。swap無効とcgroup chargeにより実メモリ使用を制限するhost profileとして評価する。kernelのcharging/shared-page semanticsと一時超過の可能性があるため、全瞬間のRSSが必ず1GiB未満という定理にはしない。[Linux cgroup v2仕様](https://docs.kernel.org/admin-guide/cgroup-v2.html)

`RLIMIT_AS`/`ulimit -v` は仮想アドレス上限であり、stock runtimeの8GiB corpus等の予約と両立しない可能性が高い。1GiB ASでの起動失敗は診断用negative結果であり、1GiB実メモリ制限成功ではない。Linuxの `RLIMIT_RSS` も代替の実効hard RSS capとして使わない。定期RSS監視後killだけではovershootを防げない。[getrlimit(2)](https://man7.org/linux/man-pages/man2/getrlimit.2.html)

厳密な「RSS全量が常に1GiB以下」という別契約を必要とする場合はこの方式の結果で満たしたとせず、追加設計が必要としてblockする。DESIGNのprocess-memory ceilingをこのkernel-charged方式として具体化した旨をresults/compatibilityに明記する。

### 6.2 実施手順・negative cases

現在の作業環境について、親担当のread-only調査では Debian 13 x86_64、kernel 6.18.57、`/sys/fs/cgroup` は `cgroup2 ro,...,nsdelegate`、既存 `memory.max` は17179869184（16GiB）だった。ClangはPATH上に未検出。この環境で専用1GiB cgroupを設定できたという証拠はなく、read-only mountでは本計画の設定経路を使えない。親cgroup/hostの設定変更やremountは行わず、controllerを委譲された別の検証host/CIでU5を行う。現環境の16GiB設定やローカルskipは1GiB成立の証拠にならない。

1. delegated cgroup controllerの存在・書込可能性を読み取り/専用leaf作成で検証。既存共有cgroupのlimitは変更しない。root cgroupやrunner全体を制限しない。未提供ならunsupportedを返してstressを開始しない。
2. limit設定・readbackとchild所属を、Bendのexec/最初のallocationより前に保証する。launch barrierまたは管理済みscope経路を使い、exec後に移すraceを作らない。子孫が同じcgroupであることも確認する。
3. baseline binary、P08のmany-chunk、256MiB charge境界の代表形をその条件で実行し、RSSとcgroup valuesを並記する。VMの大きさで誤判定しない。
4. graceful live-budget exhaustionを起こし、想定した非zero exitと診断、scratch-onlyの状態を確認する。OS上限とは独立したBend側のreserve拒否であることを示す。
5. Bendが保持してtouchするArray群を使い、test-onlyにlive guardを越える別probeでcgroup OOMを誘発する。まず低い専用limitでharnessを検証し、最後に実1GiB設定を測る。設計予算の実装をホストによるallocationに置き換えない。
6. `memory.events`（可能ならlocal events）のbefore/after、oom/oom_kill、processのsignal/status、memory.peakを記録。SIGKILLだけでOOMと断定しない。kernel peakが厳密にmaxと等しいことを要求せず、設定・発火・終了・実測を併記する。
7. malloc/realloc失敗を対象IO buffer allocationに決定的に注入し、別にvirtual mapping失敗を診断する。実stock runtimeのfail-stop結果、stderr、exit/signalを観測し、例外catchや詳細reportが必ずあるとは約束しない。OS OOM killとは別test IDにする。
8. read後/write途中/完了記録前に外部SIGTERM/SIGKILLとtimeoutを入れる。監督側は未完了をfailureとして残し、子孫を回収してからcgroupを片付ける。突然死でも監督logは残る。OS signalを製品exit codeへ偽装しない。

不足時の選択肢は、同じprofileを実証できるCI/hostを用意するか、対応hostを限定してunsupportedとする。1GiB ASへの置換、CI skip→pass、共有host OOMまで無制限に走らせるfallbackは禁止する。

## 7. 公開しない構成と追加primitiveの引継ぎ U6

全probeの出力先はharnessが作成したprivate scratch内の固定fixture名だけに限定する。productionのoutput-dirを受け取らず、bundle manifest/completion markerも作らず、rename/publication経路は存在させない。失敗・kill後は未検証scratchとして扱う。入力digest・既存destination sentinelが不変、publishを模した監視directoryがemptyのまま、成功扱いのresultがないことを外部harnessで検証する。任意のユーザーpathを再帰削除するcleanupは作らない。

これは「公開コードがない実験構成」の検証であり、productionのnamespace race耐性やatomic publicationの証明ではない。staging-onlyという呼び名で将来のsafe stage基盤を先行完成扱いしない。

| 後続で必要な能力 | stock/sourceからのgapまたは未証明点 | Issue #1での扱い |
| --- | --- | --- |
| checked close、file/directory fsync | closeがerrorを捨て、Baseにfsyncなし | insufficiencyを記録、durable write/publish blocked |
| errorを保持するread、必要ならbounded direct-buffer IO | partial-read error喪失、List変換cost | 注入と測定でrequirements確定。production primitive実装は後続 |
| fstat identity/type/size、no-follow、dirfd相対open | path-based open/sizeだけではsnapshot/namespace契約を満たさない | secure input snapshot/cleanup blocked |
| private directory作成とACL/owner/ancestor検査、held parent descriptors | current stock file APIでは不足 | 後続OS substrateに必要な契約を列挙 |
| rename-no-replace、bottom-up fsync、source/destination parent sync | stock APIでatomic bundle publish不成立 | atomic publishは常にblocked |
| trusted supervisor/cgroup resource controller | hostによってdelegationとmemory controllerが異なる | 実証されたhostのみresource-limit verified。生binary直起動は同保証外 |

必要性を明確にするためのtest-only C wrapperは可だが、secure mkdir/openat/ACL/rename/cleanupのproduction実装に範囲を広げない。後続では同じcompiler pinのままprimitiveを足してもnative build artifactとprobe結果を更新する。

## 8. 予定ファイルと実装順序

| 単位 | 予定ファイル | 完了条件・依存 |
| --- | --- | --- |
| U1 provenance/host lock | `sources.lock`, `tools/runtime/fetch_toolchain.py`, `tools/runtime/verify_lock.py`, `docs/runtime/toolchain.md`, 必要な `third_party/licenses/` | exact pins/取得digest/license確認、clean fetch再現。先行なし |
| U2 build/runner | `tools/runtime/build_probes.py`, `tools/runtime/run_probes.py`, `tests/runtime/cases.json`, `tests/runtime/oracle.py` | source check/native build/実行を分離、machine-readable結果、unknown flag拒否。U1後 |
| U3 Bend probes | `tests/runtime/probes/{argv_exit,binary_roundtrip,offsets,exclusive_create,io_errors,short_io,affine_arrays,chunk_stream,sha_primitives}.bend`, `tests/runtime/negative/` | P01–P09とoracle/expected failure、所有権負例。U2後 |
| U4 representation/work | `tests/runtime/probes/{budget_work,memory_shapes}.bend`, `tests/runtime/fixtures/generate.py`, `tools/runtime/measure.py`, `docs/runtime/resource-model.md` | charge式・定量記録・counter/plateau試験。大stressはU5導入後 |
| U5 OS ceiling/faults | `tools/runtime/limited_run.py`, `tests/runtime/native/fault_inject.c`, `tests/runtime/probes/memory_pressure.bend` | 1GiB cgroup、graceful予算拒否、host allocation失敗、killの別結果。U2とU3最小case後 |
| U6 report/CI | `.github/workflows/runtime-probes.yml`, `docs/runtime/README.md`, `docs/runtime/capabilities.md`, `docs/runtime/evidence/<run-id>.*` | 下記gates、Linuxネイティブ対応表、blocker・対象外・未実施明記。U1–U5結果に依存 |

名前は計画上の候補。必要のない抽象化やprod moduleを追加しない。generated C/native binaries、large fixtures、compiler cache、scratchはversion管理せず、`.gitignore`に局所的に追加する。small expected vectors/テスト仕様とsanitized evidence summaryをcommitし、full logsはCI artifactに保存する。artifact manifestにhashを残す。DESIGNとDESIGN_REVIEWの履歴的主張は勝手に書き換えない。

依存順は **U1 → U2 → U3最小IO → U5隔離 → U3全体/U4測定 → U6**。本計画レビュー完了前にいずれも着手しない。U1 exact host pins未確定、compiler不調、isolation不足などは早期に検出し、後続大量実装の前にblockする。

## 9. CI・PR・Issue完了 gates

### CI

- PRごと: lock schema/digest、source取得、check/native build、P01–P10小規模、negative ownership、short IOとerror injection、small-limit cgroup harness test、成果物とログの保存。workflowはread-only repo permission、第三者actionsはfull SHA、secret不要。
- full-resource job: 実1GiB cgroup上限、実charge境界、long-stream plateau、allocation failure、OOM/kill、sparse offset境界。supported Linux runnerで実施し、resource gateとして必須。環境がcontrollerを提供しなければstatusはunsupported/failedでありsuccessにしない。
- WSL2 はこの Issue の必須 CI・受入 checklist に含めない。追加要望があった場合は別 profile として distro/kernel/Windows host build/filesystem と cgroup 能力を記録し、Linux filesystem（例: distro側ext4）上で同じ suite を再実行してから対応を判断する。`/mnt/c` などの Windows-mounted FS は別途検証が必要。Linux 結果を WSL の実測と偽らない。
- backend/arch/worker数が変われば別profileとして再測定。CIのcache hitだけに依存せずclean-fetch runを含める。failureでも有限サイズのlogsを保存する。

### PRレビューで確認するもの

1. この計画の独立Astraレビュー記録: reviewer/model、入力計画hash、findings、修正と再レビュー、残存blockers。レビューが終わるまでコード実装しない。
2. 実装PRのscopeはruntime experiments/tools/docs/CIだけ。Bend probeが演算/IOを実際に行っていることをreviewする。未承認旧実装からのコピーなし。
3. `sources.lock`に未解決placeholderがない、clean fetch/native build再現、API/flagsがruntimeで受理された証拠。
4. 各P/Uのcase IDがactual evidenceに結び付き、exit/signal、injection applied、expected failure、timeoutを区別。未実行を緑にするrunnerを拒否する。
5. 測定charge式の根拠、256MiBと1GiBの独立性、RSS/VmSize/cgroup/workの意味、未検証input上限の記載を確認する。
6. allocation failure/OOM/cancellationでも成功resultやpublish outputが出ない。production publication能力はblockedのまま。
7. Linux ネイティブの検証表が実態どおり。WSL は追加要望時の別対応・未検証と明記し、未実施 platform を対応済みにしない。WSL 未実測をこの Issue の必須受入未達として扱わない。

Issue #1を実装完了にできるのは、固定環境でrequired experimentsを実行し、計測・失敗観測・runbook・最小CIが揃った時点。発見したstock API不足を隠さず、後続blocked capabilityとprimitive requirementsを引き継ぐ。主要resource成立性が未検証なら、調査PRを取り込めてもIssueの当該受入条件は未達のままにする。これによりIssue完了とGate A全体/製品公開完成を区別する。

## 10. 現時点の未確定事項・判断待ち

| 未確定 | 解決する作業・未解決時の停止点 |
| --- | --- |
| Bun/Clang/libc/CI imageのexact version/digest | U1で実在artifactと互換性を確認。lock完成前の測定は採用結果にしない |
| source pinが実native compile/run可能か | U2。静的なAPI存在は成功証明にならない |
| stock Array/Listの実費用・live解放後のretention | U4。charge式と256MiB内workloadの成立を実測するまでmemory-safe/サイズ対応を宣言しない |
| Linux native hostでのcgroup delegation/1GiB強制 | U5。専用leafを作れない環境ではmemory-limit verifiedにしない |
| 1GiB charged-memory profileとDESIGNの契約の整合 | この計画の独立レビューで判定。strict RSS ceilingが必要なら追加設計へblock |
| partial read errorの扱い、checked-close不在 | P06実測後に後続primitive要件を確定。error-transparent/safe publishを有効化しない |
| IO malloc/arena allocation失敗の具体的exit/signal | fault injectionとOS limitで別々に測定。code5に一律変換した事実を作らない |
| 最小CIのLinux resource-capable runner | U6で確定。スキップと対応認証を分離 |

本計画時点で実施したのは Issue/DESIGN と固定 upstream source の読み取り、pin/license/API/runtimeの静的確認、Linux公式仕様の確認のみ。Bend compile/run、故障注入、メモリ測定、CI、WSL実行は **すべて未実施**。
