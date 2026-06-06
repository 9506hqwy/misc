# Compute Express Link

Linux は
[v5.12](https://github.com/torvalds/linux/commit/4cdadfd5e0a70017fec735b7b6d7f2f731842dc6)
から実装を開始している。

## コンポーネント

ACPI CXL Early Discovery Table (CEDT) の情報をもとに CXL デバイスを発見する。

![Linux コンポーネント](./images/linux-components.png)

CXL Fixed Memory Windows Structure (CFMWS) は CEDT 内にある構造体で
CXL デバイスのメモリをマッピングする Host Physical Address (HPA) の範囲を示す。
CFMWS は静的な情報のためメモリをホットプラグする場合は予め十分な HPA が必要になる。

CXL Host Bridge Structure (CHBS) は CEDT 内にある構造体で CXL Host Bridge を示す。
CXL Host Bridge には 1 個以上の CXL Root Port があり、Root Port から CXL デバイス
あるいは CXL スイッチに接続する。

CXL [root decoder](https://github.com/torvalds/linux/commit/0f157c7fa1a0e1a55b602d8b269344392e9033ad) は
System Physical Address (SPA) と HPA を変換する。
変換は Interleave Arithmetic が 01h (Modulo arithmetic combined with XOR) の場合に処理される。
また、
[AMD Zen5 の場合](https://github.com/torvalds/linux/commit/af74daf91652f15b82560bb93850d2ec8bbfa976)
も root decoder でアドレス変換が行われる。
[無効化](https://github.com/torvalds/linux/commit/208f432406b7ed446c061d68cc73efd85b575d3f)
されている？

- [SPA to HPA](https://github.com/torvalds/linux/commit/b83ee9614a3ec196111f0ae54335b99700f78b45)
- [HPA to SPA](https://github.com/torvalds/linux/commit/3b2fedcd75e3991e77c2a8c3ebcab0ea68b2d69d)

CXL [switch decoder](https://github.com/torvalds/linux/commit/e636479e2f1b611892783405a302221e4f069e4f) は
Up Stream Port (UDP) を Down Stream Port (DSP) をルーティングする。

CXL [endpoint decoder](https://github.com/torvalds/linux/commit/3bf65915cefa879e3693a824d8801a08e4778619) は
HPA と Device Physical Address (DPA) を変換する。

- [SPA to DPA](https://github.com/torvalds/linux/commit/dc181170491bda9944f95ca39017667fe7fd767d)
- [DPA to HPA](https://github.com/torvalds/linux/commit/28a3ae4ff66c622448f5dfb7416bbe753e182eb4)

CXL1.1 互換トポロジとして Restricted CXL Host (RCH) と Restricted CXL Device (RCD) がある。

## 使用方法

SPA にマップされたメモリ領域の CXL リージョンを作成する。
リージョンはシステムメモリ(ram)か永続化メモリ(pmem)を指定して
[作成](https://github.com/pmem/ndctl/commit/21b089025178442baa7b59823a7fd264b4c075a8)
する。

- システムメモリは sysfs の
  [create_ram_region](https://github.com/torvalds/linux/commit/6e099264185d05f50400ea494f5029264a4fe995)
  を
  [実行](https://github.com/pmem/ndctl/commit/aa8ae068752a9a3b01c012259b9210e14d7245a4)
  する。
- 永続化メモリは sysfs の
  [create_pmem_region](https://github.com/torvalds/linux/commit/779dd20cfb56c510f89877cca45529fa9f8bc450)
  を
  [実行](https://github.com/pmem/ndctl/commit/cafe4b2d4970b0d7f2193abb9cb32f58c03cbe3b)
  する。

システムメモリを作成すると NUMA ノード (*/sys/devices/system/node*) が
[構成](https://github.com/pmem/ndctl/commit/e8bf803e359b784259f645d1ff68e964b2c8618f)
される。主記憶として利用できる。

永続化メモリを作成すると不揮発性メモリ (*/sys/class/nd*) にリージョンが
[構成](https://github.com/pmem/ndctl/blob/v84/ndctl/libndctl.h#L19-L60)
される。NVDIMM として利用できる。

NVDIMM のアクセス方法は 3 つある。

- 通常のファイルシステム (sector)
- DAX 対応のファイルシステム (fsdax)
- DAX デバイスファイル (devdax)

## 参考

- [CXL Specification](https://computeexpresslink.org/cxl-specification/)
- [UEFI Specifications](https://uefi.org/specifications)
- [Compute Express Link](https://docs.kernel.org/driver-api/cxl/index.html)
  - [bend or break CXL specification expectations](https://docs.kernel.org/driver-api/cxl/conventions.html)
- [pmem.io](https://pmem.io/)
