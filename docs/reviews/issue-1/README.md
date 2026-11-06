# Issue #1 レビューと修正履歴

ユーザー指定に従い、Astraが計画を作成し、別のAstraが計画をレビューした後に実装を開始しました。各実装レビューも新しいAstraです。実装範囲はIssue #1の実験基盤だけです。

| 段階 | 記録 | 結果・対応 |
| --- | --- | --- |
| 計画 | [実装計画](../../implementation/issue-1-plan.md) | DESIGNとIssue本文を読み、範囲・pin・実験・未対応時の停止条件を整理 |
| 計画レビュー1 | [plan-01](plan-01.md) | 追加の実装阻害指摘なし |
| 実装レビュー1 | [implementation-01](implementation-01.md) | 4件。JSON handoffのatomic化、実I/O中断試験、4095境界の実分割とretry内容検証、checked range probeを追加 |
| 実装レビュー2 | [implementation-02](implementation-02.md) | 2件。全入力fingerprintとビルド無効化/atomic完了、suiteの完了・範囲・全case identity照合を追加 |
| 実装レビュー3 | [implementation-03](implementation-03.md) | 2件。集計関数の名前隠蔽を修正、実行開始時の旧suite完了記録をatomicに無効化。修正再確認後、静的な残存指摘なし |
| 実装レビュー4 | [implementation-04](implementation-04.md) | 追加指摘なし。191件の全observation、指紋、case inventory、測定値・保存fixtureのoracle再検証を行い、Linux実験の範囲で受理 |

レビュー3の修正後、`python3 tools/runtime/test_evidence.py` の13テストを実装担当とAstraがそれぞれ実行して成功しました。lock/recipe/binary変更、partial/失敗build、prefix/重複/失敗suite、実行snapshot不一致、resource runnerの完了処理、`os._exit`による両runnerの突然死を含みます。これらはnative probeやOS制限の代替ではありません。

最終native検証は固定buildから全191ケースを再実行し成功しました。旧版の途中結果や明示中断したrunを完了証拠に採用しません。レビュー記録の「pending」は各レビュー時点の履歴であり、最終状態はこの索引・runtime evidence・PRのCIを確認してください。

未解決の環境制約はWSL2の実測ができないことです。stock APIのpartial-read error消失・checked close不在などは実測された後続primitive要件として残し、このIssueで安全なpublish能力を宣言しません。Issue #1を自動closeするPR本文にはしません。
