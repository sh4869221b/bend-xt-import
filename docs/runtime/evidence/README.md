# Linux final local evidence

最終固定buildから **API 93ケース、resource 98ケース、計191ケース** が全て実行され、expected case inventory・complete marker・全入力fingerprintの照合が成功しました。別にevidence regression 13テストと、Array/File各1つの型検査負例・正常対照が通っています。

実行したコマンドはリポジトリルートで `python3 tools/runtime/bootstrap.py --cache .cache/reproduce-2` → `python3 tools/runtime/run_probes.py` → `python3 tools/runtime/measure.py` → `python3 tools/runtime/summarize.py` です。regressionは `python3 tools/runtime/test_evidence.py`。API・resource suiteは順次実行しました。二つの新しいcacheへの独立取得でBend/Bunのdigest一致も確認しました。最終ローカルimage buildはDocker layer cacheを利用しており、全packageを毎回再ダウンロードしたという主張ではありません。bit-for-bit reproducible buildの一般保証もしていません。

- [linux-summary.json](linux-summary.json): 191ケースの判定・終了状態・制限値・個別observation digest、表現とstreamのmin/median/max、実行入力のdigest。
- [linux-build.json](linux-build.json): 14 Bend probeのtypecheck/native/C生成、2 C helperのdigest、所有権対照、使用commandと完全な入力fingerprint。
- [linux-environment.json](linux-environment.json): 実測kernel、Python、Docker、image ID。

build record SHA-256: `41fd62e392bee1ba6b77a3feddceb3bd4d579cd0267ba79dcfc675ab2801a8e2`。

## 代表値（bytes）

| ケース | native sampled VmHWM | cgroup peak |
| --- | ---: | ---: |
| charge 256MiB / 実U32 payload64MiB | 69,578,752 | 74,514,432 |
| raw index payload256MiB（guardを通らない別実験） | 270,974,976 | 276,135,936 |
| 1GiB OOM | 1,063,223,296 | 1,073,741,824 |

1GiB OOMでは `oom_kill: 0 → 1` とDocker OOM状態を確認し、外部killとは区別しました。cgroup peakはnative RSSと別量です。

| stream入力 | native VmHWM min / median / max（3回） |
| --- | --- |
| 1MiB | 5,734,400 / 5,738,496 / 5,767,168 |
| 16MiB | 5,664,768 / 5,668,864 / 5,668,864 |
| 64MiB | 5,599,232 / 5,664,768 / 5,795,840 |

この範囲ではnative RSSの大幅な増加は観測されませんでした。64MiB streamのcgroup peakは最大79,093,760 bytesで、出力file cacheとhelperも含みます。一般の実形式・入力上限への外挿はしません。

full raw observationsとscratchは作業環境の `runs/` にあり、Gitには含めていません。CIは同じsuiteを独立実行し、自身のbuild/observation/suite JSONとbounded logsをartifactへ保存します。CI artifactはそのCI runの証拠であり、ローカル観測ファイルと同一だとは主張しません。

途中の旧実装run、明示中断run、review修正前の集計はこの最終evidenceに含めていません。既知API不足はverified_gapとして残っています。WSL2、実MOD/ゲーム、製品publishは未検証・未実装です。
