# Issue #1: Bend 2 runtime experiments

このディレクトリは固定した Bend 2 から実際に native binary を生成して動かす実験基盤です。MOD/XML parser、翻訳 CLI、製品用 filesystem primitive、SHA-256 本体は実装していません。[能力表](capabilities.md)と[リソースモデル](resource-model.md)を参照してください。

## 実行

必要条件は Linux x86_64、Python 3、ローカル Docker Engine/buildx、cgroup v2 の memory controller、非 root の実行ユーザーです。そのユーザーがローカル Docker socket を利用でき、専用コンテナの cgroup を `/sys/fs/cgroup` と `/proc` から読める必要があります。共有 cgroup の設定は変更しません。Linux ネイティブでの実行に WSL は不要です。WSL2 は未検証で、初期対応・Issue #1 の必須受入条件には含めず、追加要望時に別途検証します。Windows-mounted filesystem、GPU、ARM、複数 worker はこの profile の対象外です。

リポジトリルートで実行します。

```sh
python3 tools/runtime/bootstrap.py
python3 tools/runtime/run_probes.py
python3 tools/runtime/measure.py
```

`bootstrap.py` は `sources.lock` の2つの配布物を `.cache/downloads` に取得して SHA-256 を確認し、固定 Debian image/snapshot から compiler 用と実行用の2つの image を作ります。Bun、Bend の Base/effects、Clang/libc/Python の package manifest を照合してから、ネットワークなしで全 probe を typecheck/native build します。download のみを再確認する場合は `fetch_toolchain.py --cache <新しい専用ディレクトリ>`、image の cache も使わない場合は `bootstrap.py --no-cache` を使います。CA の場所は `--ca` で指定できます。TLS 検証は無効化しません。

Docker は `unix:///var/run/docker.sock` に限定します。endpoint/context/TLS selector だけを子プロセス環境から外し、認証用 `DOCKER_CONFIG`、proxy、CA 設定は保持します。コンパイルは固定 source directory から Bun の `--no-env-file` を付けて行い、Bend telemetry と GPU を無効にします。ホスト上の他の Bend executable は使用しません。

`run_probes.py --group io|arithmetic|faults` と `measure.py --group budget|shapes|stress|stream` で系列を選択できます。測定結果の比較には suite を順次実行してください。`stress` は実際に専用 cgroup の OOM を誘発します。監督・コンパイラはその cgroup の外にあります。**native stress binary を直接起動しないでください。** isolation/readback/child identity の確認に失敗したら、上限のない実行へ切り替えず失敗します。

## 結果

`build/build.json` はソース・生成C・native binary の digest、実コマンド、所有権負例と対照の診断を含みます。`build/environment.json` は kernel、host Python、Docker、image ID です。`runs/suite-*.json` と `runs/measure-*.json` はケース一覧、個別 `observation.json` は終了状態、制限値、cgroup events、RSS/VM sampling、入出力、故障注入 trace への対応です。短命プロセスでは sampling が欠けることがあります。欠測を0として解釈しないでください。

`.github/workflows/runtime-probes.yml` は同じ全 suite を実行します。Ubuntu runner label は kernel/host の完全な pin ではないため、毎回その値を記録します。実行 userland と compiler は lock に固定しています。CI artifact にはサイズを制限したログと JSON を保存し、64 MiB fixture、cache、binary、生成Cは含めません。CI job に skip fallback はありません。

全 probe は harness 所有の `runs/<case>/` の合成 fixture にだけ書き込みます。元ファイルを保つテストと、書き込みAPIを試すため意図的に変更する `P03-position` fixture は区別しています。既存 destination の sentinel と空の published directory を各試験の終了後に確認します。成功した read/write、OOM、kill 試験は **製品の atomic publication の証明ではありません**。製品の publish 経路自体がありません。

失敗した scratch は診断用に残ります。任意のユーザーパスを削除する cleanup は提供しません。ログを保管した後、所有者がこの実験用 `build/`、`runs/`、`.cache/` を必要に応じて片付けてください。

## 固定した入力・ライセンス

- Bend `266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae` / version 2.0.40: Apache-2.0。source archive 全体を取得し、LICENSE を保持して展開。
- Bun 1.3.2 baseline x64: MIT、同梱依存には別ライセンスあり。lock の LICENSE.md を参照。
- Debian/Clang/libc/Python:各 package の `/usr/share/doc/<package>/copyright` を image 内に保持。
- xTranslator/xEdit:設計の参照元として revision と MPL-2.0 を記録。ビルド依存・ソースコピーではない。
- CI Actions: full commit SHA と license reference は lock に記録。

配布用の importer/artifact は作成していません。旧実装ディレクトリのコードは使用していません。計画とレビュー履歴は [implementation plan](../implementation/issue-1-plan.md)、[reviews](../reviews/issue-1/) にあります。計画中の「未実施」は計画作成時点の履歴です。現在の検証状態は能力表・evidence・CI run を基準にしてください。
