# Universally Unique IDentifiers (UUIDs)

Globally Unique Identifier (GUID) 形式の識別子となる。

```text
xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx
```

`M` は 4 bit で構成され UUID のバージョンを示す。

`N` は 2-4 bit で構成され UUID のレイアウトを示す。RFC 9562 では `0b10` となる。

## UUID version 1

下記の情報から構成する。

- 1582/10/15 00:00:00.00 からのタイムスタンプ (100 nano sec)
- クロックシーケンス
- MAC アドレス

```sh
python -c "import uuid; print(uuid.uuid1())"
```

```text
f6bff6eb-ae3e-11f1-9e75-00155D002605
```

| 項目       | 長さ[bit] | 値[hex]      |
| :--------- | :-------- | :----------- |
| time_low   | 32        | f6bff6eb     |
| time_mid   | 16        | ae3e         |
| version    | 4         | 1            |
| time_hight | 12        | 1f1          |
| variant    | 2         | 2            |
| clock_seq  | 14        | 1e75         |
| node       | 48        | 00155D002605 |

タイムスタンプは `0x1f1ae3ef6bff6eb` は 2026/09/12 00:14:47 になる。

```python
from datetime import datetime, timedelta

base = datetime.strptime("1582-10-15 00:00:00", "%Y-%m-%d %H:%M:%S")
timestamp = timedelta(microseconds=140_084_648_876_177_131 / 10)
print(base + timestamp)
```

```text
2026-09-12 00:14:47.617714
```

node は MAC アドレス 00-15-5D-00-26-05 になる。

## UUID version 2

RFC 9562 の範囲外になる。

## UUID version 3

下記の情報から構成する。

- 名前空間
- 名前

名前空間 ID 値は下記の定義がある。

| 名前空間 | 値                                   |
| :------- | :----------------------------------- |
| DNS      | 6ba7b810-9dad-11d1-80b4-00c04fd430c8 |
| URL      | 6ba7b811-9dad-11d1-80b4-00c04fd430c8 |
| OID      | 6ba7b812-9dad-11d1-80b4-00c04fd430c8 |
| X500     | 6ba7b814-9dad-11d1-80b4-00c04fd430c8 |

```sh
python -c "import uuid; print(uuid.uuid3(uuid.NAMESPACE_DNS, b'value'))"
```

```text
aa0235da-8c69-3095-a4fa-a74cecfc4764
```

| 項目     | 長さ[bit] | 値[hex]          |
| :------- | :-------- | :--------------- |
| md5_high | 48        | aa0235da8c69     |
| version  | 4         | 3                |
| md5_mid  | 12        | 095              |
| variant  | 2         | 2                |
| md5_low  | 62        | 24faa74cecfc4764 |

MD5 ハッシュ値は `0xaa0235da8c69e09524faa74cecfc4764` になる。

```python
from hashlib import md5
import uuid

ns = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
v = ns.bytes + b'value'
print(md5(v).hexdigest())
```

```text
aa0235da8c69e09524faa74cecfc4764
```

version と variant をビット置換する。

## UUID version 4

下記の情報から構成する。

- ランダム値

```sh
python -c "import uuid; print(uuid.uuid4())"
```

```text
a7071853-15f3-436f-9873-74fa371c791a
```

| 項目     | 長さ[bit] | 値[hex]           |
| :------- | :-------- | :---------------- |
| random_a | 48        | a707185315f3      |
| version  | 4         | 3                 |
| random_b | 12        | 36f               |
| variant  | 2         | 2                 |
| random_c | 62        | 1987374fa371c791a |

## UUID version 5

下記の情報から構成する。

- 名前空間
- 名前

```sh
python -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, b'value'))"
```

```text
55236758-382f-5086-ac20-38d9530decea
```

| 項目      | 長さ[bit] | 値[hex]          |
| :-------- | :-------- | :--------------- |
| sha1_high | 48        | 55236758382f     |
| version   | 4         | 5                |
| sha1_mid  | 12        | 086              |
| variant   | 2         | 2                |
| sha1_low  | 62        | 2c2038d9530decea |

SHA1 ハッシュ値は `0x55236758382f0862c2038d9530decea` になる。

```python
from hashlib import sha1
import uuid

ns = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
v = ns.bytes + b'value'
print(sha1(v).hexdigest())
```

```text
55236758382fc086ac2038d9530deceaf6674564
```

version と variant をビット置換して 128 bit で切る。

## UUID version 6

下記の情報から構成する。

- 1582/10/15 00:00:00.00 からのタイムスタンプ (100 nano sec)
- クロックシーケンス
- MAC アドレス

```sh
python -c "import uuid; print(uuid.uuid6())"
```

```text
1f1ae4f6-3830-6af4-ae36-00155D002605
```

| 項目      | 長さ[bit] | 値[hex]      |
| :-------- | :-------- | :----------- |
| time_high | 32        | 1f1ae4f6     |
| time_mid  | 16        | 3830         |
| version   | 4         | 6            |
| time_low  | 12        | af4          |
| variant   | 2         | 2            |
| clock_seq | 14        | 2e36         |
| node      | 48        | 00155D002605 |

タイムスタンプは `0x1f1ae4f63830af4` は 2026/09/12 02:12:22 になる。

```python
from datetime import datetime, timedelta

base = datetime.strptime("1582-10-15 00:00:00", "%Y-%m-%d %H:%M:%S")
timestamp = timedelta(microseconds=140_084_719_420_377_844 / 10)
print(base + timestamp)
```

```text
2026-09-12 02:12:22.037784
```

node は MAC アドレス 00-15-5D-00-26-05 になる。

## UUID version 7

下記の情報から構成する。

- 1970/01/01 00:00:00.00 からのタイムスタンプ (milli sec)
- ランダム値

```sh
python -c "import uuid; print(uuid.uuid7())"
```

```text
01a09377-1b0e-7239-8502-66f76e2f8a04
```

| 項目       | 長さ[bit] | 値[hex]          |
| :--------- | :-------- | :--------------- |
| unix_ts_ms | 48        | 01a093771b0e     |
| version    | 4         | 7                |
| rand_a     | 12        | 239              |
| variant    | 2         | 2                |
| rand_b     | 62        | 050266f76e2f8a04 |

タイムスタンプは `0x01a093771b0e` は 2026/09/12 02:34:11 になる。

```python
from datetime import datetime, UTC

print(datetime.fromtimestamp(1_789_180_451_598 / 1000, UTC))
```

```text
2026-09-12 02:34:11.598000+00:00
```

## UUID version 8

下記の情報から構成する。

- 任意の値

```sh
python -c "import uuid; print(uuid.uuid8(a=1, b=2, c=3))"
```

```text
00000000-0001-8002-8000-000000000003
```

| 項目     | 長さ[bit] | 値[hex]          |
| :------- | :-------- | :--------------- |
| custom_a | 48        | 000000000001     |
| version  | 4         | 8                |
| custom_b | 12        | 002              |
| variant  | 2         | 2                |
| custom_c | 62        | 0000000000000003 |

## 参考

- [Universally Unique IDentifiers (UUIDs)](https://www.rfc-editor.org/rfc/rfc9562.txt)
