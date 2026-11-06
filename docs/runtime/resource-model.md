# 資源の意味と実験 profile

`268435456` bytes は live payload/index charge、`1073741824` bytes は専用 cgroup v2 の kernel charged memory 上限です。後者は per-process RSS や virtual address size の厳密な上限ではありません。swapは0。kernel・共有ページ・file cacheの算定があるため、cgroup量とRSSを同一視しません。stock runtimeは約10 GiB以上の仮想領域を予約し、1 GiBのRLIMIT_ASでは起動できません。この診断をRSS制限の成功とは扱いません。

## 測定の境界

native実行前に専用containerを作り、内外のmemory.max/swap.max、native childのcgroup所属を確認してからexec barrierを解放します。compilerとhost supervisorは外側です。固定Pythonの小さなreaperだけが同じcgroupに残り、wait4の最終status/ru_maxrssを保存します。このhelperのメモリも上限に含みます。SIGTERMはnative childへ転送し、SIGKILLはcontainer全体を停止します。

`/proc/<native-pid>/status` を20 ms周期で読み、exec後のNameを確認してVmRSS/VmHWM/VmSizeを記録します。短命caseには欠測があります。wait4のru_maxrssにはexec前のPython barrierの高水位も含まれ、nativeだけのpeakとして扱いません。SIGKILLでhelperも終了した場合、最終rusageがないことを明示します。OOMはDockerの状態とcgroup oom_killの増分を要求し、exit137だけでは合格にしません。

OOM後にhelperが残る場合はfinal cgroup events/peakを読んでからhelperを解放します。公開経路のない合成scratch実験であり、kill後の製品cleanup・atomic publishを証明しません。

## 生成Cから確認した表現

根拠は固定compilerの `blk_new/blk_ptr/blk_copy/heap_alloc/cls_fit` と各probeの生成Cです。生成Cのdigestはbuild recordに残ります。`Term=u64`だけから全オブジェクトのコストを推定していません。

| 実験形 | payloadのlayout | 状態 |
| --- | --- | --- |
| Array<U32> | BUF、1要素4 bytes、2^depth capacity。小さいclassは最小8 bytes | 実測対象。一般的なArray<T>への外挿は不可 |
| Array<Index{U32,U32,U32}> | BUF、4 U32分に丸められた16 bytes/要素 | 固定3項目形のみ。raw256MiBも隔離内で測定 |
| List<U32> | Consに2 words=16 bytes、共有時の参照cell等は別 | 生成/消費/共有でtemporariesが異なるためproduction chargeはblocked |
| String | コードポイント列と生成中の継続/共有を含む | ASCII/日/😀を別測定。UTF-8 byte数をmemory costにしない |
| conversion | 入力List + Array + clone + 再構成List +一時継続 | 64KiB試験のpeakを観測。一般式はblocked |

`heap_alloc`の保持class/free list、page quantum、continuation、stack、IO host bufferはpayloadの外にも存在します。live値の消費・予約返却後にRSSが下がるとは限りません。

## 限定した live charge 実験

`charged_array.bend` だけは、touchしてchecksumを消費する1つのU32配列に対して `max(65536, 16 * 2^depth)` を確保前に予約します。depth<=24の事前guardによりU32乗算は溢れません。4 bytes/要素の実payloadに対し残り12 bytes/要素（小形では最低64KiB）が固定profileの一時値・測定marginです。2^24要素でchargeちょうど256MiB、実payload64MiBです。3回の確保・保持・消費・予約返却を試し、limitを1byte下げると配列生成前にexit5になります。

これは当該probeに限定した保守的な実験chargeであり、任意の呼出し・resize・clone・複数buffer・他の型に対する上限証明ではありません。実際のraw256MiB索引配列の実験はlive guardを意図的に通らない別caseで、256MiB予算の合格には数えません。製品の共通allocator/予約台帳は後続Issueです。

`budget_work.bend` の小配列allocationは**synthetic cost**です。上限ちょうど/1超過、U32 wrap、乗算overflow、release underflowを巨大allocationなしで試します。`work`は同じListの全passで訪問数を減算し続けます。共有したListでも無料にせず、各passでリセットしません。実read/decode/verification phaseごとの製品counterは未実装です。

## 系列・判定

shapeはdepth8/16/20、baseline/array/list/index/ASCII/日本語/非BMP/conversion、各3run、runごと3allocation/dropを測定します。保持時と消費後はstdout markerとsamplingを対応させます。streamは64KiB chunkで1/16/64MiB、各3runを処理し、外部SHA-256 oracleで全入力と出力を照合します（このoracleはBend SHA実装ではありません）。初期測定ではnative RSSの大幅な増加はなく、出力file cacheによるcgroup charge増加がありました。具体的なmin/median/maxは保存したevidenceを参照してください。64MiBより大きい入力、全ての実MOD構造のbounded-memoryを認定しません。

任意のnested index、非power-of-two logical lengthの一般式、全conversion経路、すべてのhost差を網羅していません。実データの最大入力・索引数を宣言するには後続実装ごとの同じ測定とcharge検証が必要です。WSL2は未測定です。
