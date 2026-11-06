# 機能別の結果と後続への制約

この表は Linux x86_64 / CPU 1 worker / lock に固定した Bend 2 C backend の実験です。`verified_gap` は不足を再現した実験の成功であり、その API が安全な製品要件を満たしたという意味ではありません。全て合成入力です。ゲーム・実 MOD・xTranslator XML は検証していません。

| 系列 | 確認する挙動 | 判定と境界 |
| --- | --- | --- |
| P01 | raw argv、空白/日本語/非UTF-8、runtime 引数除去、exit 0/2–7、die | native 実行で oracle と照合。製品の引数仕様ではない |
| P02/P08 | NUL を含む全 byte、0/1/65535/65536/65537/131073 bytes、64 KiB chunk | 内容・長さを外部 oracle と照合。Array→List の quantity 変換を明示 |
| P03 | cursor 非変更の read_at/write_at、zero read、UINT32_MAX file size/last byte | U32 より大きい file size は EOVERFLOW。64-bit offset 対応ではない |
| P04 | x mode、既存 file/directory/symlink、2プロセスの競合 | 既存対象を壊さず1件だけ作成。safe parent/dirfd/ACL の証明ではない |
| P05 | ENOENT/EACCES/EINVAL/EBADF/ENOSPC、256以上のbyte拒否 | 対象 fixture だけで検証。製品エラー分類は後続 |
| P06 | read/pread/write/pwrite の short IO、EINTR、EIO、zero、prefix後失敗 | write失敗は通知されるが未完了prefixが残る。未検証出力として扱う |
| P06 gap | 部分 read → EIO、一度だけEIO → 次回成功 | **error-transparent read は blocked**。最終sizeが合ってもエラー消失を検出できない |
| P06 gap | 実close後のEIO | **checked close は blocked**。stock API は失敗を捨てる |
| P06 allocation | host malloc/realloc 失敗注入 | fail-stop。製品 exit 5 の保証ではない |
| P07 | Array/File affine 二重消費の型検査負例と正常対照 | Array.get は添字をmaskする。製品境界検査を代替しない |
| P09 | U32演算・shift・rotate・endianness・carry・16/64word状態 | SHA-256 に必要な演算の例。**SHA-256 実装やdigest検証ではない** |
| P10 | checked予約/解放/乗算、累積byte訪問、境界 | syntheticカウンタと実際のList反復を区別。codec/parser のwork計測は未実装 |
| M | 実表現、live予算試験、stream、1GiB cgroup、OOM/signals/timeout | 適用範囲と定量値は resource-model.md と evidence を参照 |

## 後続で必要な能力

- partial read error を失わない primitive、結果を返す close、file/directory fsync。
- fstat identity/type/size、no-follow、dirfd 相対 open、private parent/staging ownership/ACL検証。
- rename-no-replace、source/destination parent の永続化、公開前後の監査契約。
- production 用の表現別 charge、すべての入力経路の事前 checked arithmetic / capacity / logical length 検査、実 parser の work budget。

上記をこの Issue で追加していません。元データ保護・安全な snapshot・durable/atomic publish は引き続き blocked です。stockのclose成功表示やerror後のsize一致を根拠に有効化してはいけません。

## 未検証・完了に含めない項目

WSL2 は実行可能な環境がなく未検証です。WSL/WSL2 を必須とした従来の記載は、ユーザー指定でない仮定を要件化したものとして訂正しました。Linux ネイティブの利用前提・Issue #1 の受入条件ではなく、未実測をその完了のブロッカーにしません。追加要望時は Windows host build / WSL kernel / distro / Linux filesystem / cgroup readback を記録して同じ全 suite を再実行し、別 profile として対応可否を判断します。この訂正は WSL 検証の成功や Native Windows 対応の不要を意味しません。

nested/boxed index、全tuple幅、実形式データ、任意の入力最大サイズ、GPU/JS/複数worker/他architectureも未認定です。Issue #1 と Gate A 全体の完了は別です。
