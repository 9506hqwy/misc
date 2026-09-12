# Universally Unique Lexicographically Sortable Identifier (ULID)

 Crockford's base32 でエンコードしたソート可能な 26 文字の識別子となる。

下記の情報から構成する。

- 1970/01/01 00:00:00.00 からのタイムスタンプ (milli sec)
- ランダム値

同一ミリ秒内はランダム値をインクリメントしてソート可能にする。

```sh
python -c "from ulid import ULID; id = ULID(); print(f'{id}\n{id.hex}')"
```

```text
01M29S86W3K95SQW9F51PY41RZ
01a093941b839a4b9bf12f286de2071f
```

| 項目                  | 長さ[bit] | 値[hex]  |
| :-------------------- | :-------- | :------- |
| 32_bit_uint_time_high | 32        | 01a09394 |
| 16_bit_uint_time_low  | 16        | 1b83     |
| 16_bit_uint_random    | 16        | 9a4b     |
| 32_bit_uint_random    | 32        | 9bf12f28 |
| 32_bit_uint_random    | 32        | 6de2071f |

タイムスタンプは `0x01a093941b83` は 2026/09/12 03:05:52 になる。

```python
from datetime import datetime, UTC

print(datetime.fromtimestamp(1_789_182_352_259 / 1000, UTC))
```

```text
2026-09-12 03:05:52.259000+00:00
```

## 参考

- [ulid/spec](https://github.com/ulid/spec)
