# QEMU を利用したエミュレーション

## ホスト環境の構築

インストール先のディスクを用意する。

```sh
virsh vol-create-as default fedora44.qcow2 64GiB --format qcow2
```

仮想マシンを作成する。

```sh
virt-install \
    --name fedora44 \
    --vcpu 4 \
    --cpu host-passthrough \
    --memory 8192 \
    --os-variant fedora42 \
    --disk /var/lib/libvirt/images/fedora44.qcow2,bus=virtio \
    --network network=public,model=virtio \
    --network network=private,model=virtio \
    --graphics vnc,listen=0.0.0.0 \
    --virt-type kvm \
    --location /mnt/Fedora-Server-dvd-x86_64-44-1.7.iso \
    --initrd-inject /root/workspace/cxl/ks.cfg \
    --extra-args="inst.ks=file:/ks.cfg console=ttyS0" \
    --noautoconsole
```

バージョンを確認する。

```sh
uname -a
```

```text
Linux localhost.localdomain 7.0.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri May 15 14:03:46 UTC 2026 x86_64 GNU/Linux
```

QEMU をインストールする。

```sh
dnf install qemu
qemu-system-x86_64 --version
```

```text
QEMU emulator version 10.2.2 (qemu-10.2.2-1.fc44)
Copyright (c) 2003-2025 Fabrice Bellard and the QEMU Project developers
```

## ゲスト環境の構築

Fedora の KVM ゲスト用のイメージを拡張しておく。

```sh
qemu-img resize disk.qcow2 +30G
```

カーネルオプション `CONFIG_CXL_REGION_INVALIDATION_TEST` が無効になっているためカーネルをビルドする。

ビルドに必要なパッケージをインストールする。

```sh
dnf install fedpkg

fedpkg clone -a kernel
cd kernel

dnf builddep kernel.spec

dnf install ccache
```

カーネルをビルドする。

```sh
git clone -b f44 --depth 1 https://src.fedoraproject.org/rpms/kernel.git src
cd src

cat >> kernel-local <<EOF
CONFIG_CXL_REGION_INVALIDATION_TEST=yes
EOF

fedpkg local --arch x86_64 --without configchecks --with baseonly
```

```text
[snip]

書き込みが完了しました: /root/workspace/src/kernel-7.0.9-205.fc44.src.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-modules-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-uki-virt-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-core-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-devel-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-modules-extra-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-modules-internal-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-uki-virt-addons-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-devel-matched-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-modules-extra-matched-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-modules-core-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-debuginfo-common-x86_64-7.0.9-205.fc44.x86_64.rpm
書き込みが完了しました: /root/workspace/src/x86_64/kernel-debuginfo-7.0.9-205.fc44.x86_64.rpm

[snip]
```

## 不揮発性メモリ

エミュレーション環境を起動する。

- ホスト側にファイル */tmp/cxl.raw* を作成し [CXL Type 3](https://github.com/qemu/qemu/commit/e1706ea83da0120be6708b66394ec3a9f3ec48ca) 不揮発性メモリとする。
- ホスト側にファイル */tmp/lsa.raw* を作成し Label Storage Area (LSA) とする。
- CXL 対応の [PCIe Expander Bridge](https://github.com/qemu/qemu/commit/4f8db8711cbd27c9acf17e685987e9e74815e087) (pxb-cxl) を作成する。
- [CXL Root Port](https://github.com/qemu/qemu/commit/d86d30192b7bc5a10fa6c82c073f55aea25f9291) (cxl-rp) を作成する。
- [CXL Fixed Memory Windows](https://github.com/qemu/qemu/commit/03b39fcf64bc958e3223e1d696f9de06de904fc6) (CFMW) を作成する。

```sh
qemu-system-x86_64 \
  -drive file=/root/disk.qcow2,format=qcow2,media=disk \
  -m size=4G,slots=8,maxmem=8G \
  -smp cores=2,sockets=1 \
  -machine type=q35,nvdimm=on,cxl=on \
  -net nic \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic \
  -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxl.raw,size=256M \
  -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,persistent-memdev=cxl-mem1,lsa=cxl-lsa1,sn=1,id=cxl-pmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G
```

※ LSA は NVDIMM のメタデータを保存する領域。

ビルドしたカーネルをゲストにインストールする。

```sh
dnf install --nogpgcheck kernel-core-7.0.9-205.fc44.x86_64.rpm kernel-modules-core-7.0.9-205.fc44.x86_64.rpm
```

CXL コマンドをインストールする。

```sh
dnf install cxl-cli daxctl ndctl
cxl version
```

```text
84
```

ACPI ツールをインストールする。

```sh
dnf install acpica-tools
```

NUMA コマンドをインストールする。

```sh
dnf install numactl
```

バージョンを確認する。

```sh
uname -a
```

```text
Linux localhost.localdomain 7.0.9-205.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Sat May 23 09:13:54 JST 2026 x86_64 GNU/Linux
```

デバイスを確認する。

```sh
lspci -tv
```

```text
-+-[0000:00]-+-00.0  Intel Corporation 82G33/G31/P35/P31 Express DRAM Controller
 |           +-01.0  Device 1234:1111
 |           +-02.0  Intel Corporation 82574L Gigabit Network Connection
 |           +-03.0  Red Hat, Inc. QEMU PCIe Expander bridge
 |           +-1f.0  Intel Corporation 82801IB (ICH9) LPC Interface Controller
 |           +-1f.2  Intel Corporation 82801IR/IO/IH (ICH9R/DO/DH) 6 port SATA Controller [AHCI mode]
 |           \-1f.3  Intel Corporation 82801I (ICH9 Family) SMBus Controller
 \-[0000:0c]---00.0-[0d]----00.0  Intel Corporation Device 0d93
```

```sh
lspci -vvv
```

```text
[snip]

0d:00.0 CXL: Intel Corporation Device 0d93 (rev 01) (prog-if 10 [CXL Memory Device (CXL 2.0 or later)])
        Subsystem: Red Hat, Inc. Device 1100
        Physical Slot: 2
        Control: I/O+ Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR+ FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
        Latency: 0
        Region 0: Memory at fe800000 (64-bit, non-prefetchable) [size=64K]
        Region 2: Memory at fe810000 (64-bit, non-prefetchable) [size=4K]
        Region 4: Memory at fe811000 (32-bit, non-prefetchable) [size=4K]
        Capabilities: [40] MSI-X: Enable+ Count=8 Masked-
                Vector table: BAR=4 offset=00000000
                PBA: BAR=4 offset=00000800
        Capabilities: [80] Express (v2) Endpoint, IntMsgNum 0
                DevCap: MaxPayload 128 bytes, PhantFunc 0, Latency L0s <64ns, L1 <1us
                        ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset- SlotPowerLimit 0W TEE-IO-
                DevCtl: CorrErr+ NonFatalErr+ FatalErr+ UnsupReq+
                        RlxdOrd- ExtTag- PhantFunc- AuxPwr- NoSnoop-
                        MaxPayload 128 bytes, MaxReadReq 128 bytes
                DevSta: CorrErr- NonFatalErr- FatalErr- UnsupReq- AuxPwr- TransPend-
                LnkCap: Port #0, Speed 32GT/s, Width x16, ASPM L0s, Exit Latency L0s <64ns
                        ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp-
                LnkCtl: ASPM Disabled; RCB 64 bytes, LnkDisable- CommClk-
                        ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt- FltModeDis-
                LnkSta: Speed 32GT/s, Width x16
                        TrErr- Train- SlotClk- DLActive- BWMgmt- ABWMgmt-
                DevCap2: Completion Timeout: Not Supported, TimeoutDis- NROPrPrP- LTR-
                         10BitTagComp- 10BitTagReq- OBFF Not Supported, ExtFmt+ EETLPPrefix+, MaxEETLPPrefixes 4
                         EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                         FRS- TPHComp- ExtTPHComp-
                         AtomicOpsCap: 32bit- 64bit- 128bitCAS-
                DevCtl2: Completion Timeout: 50us to 50ms, TimeoutDis-
                         AtomicOpsCtl: ReqEn-
                         IDOReq- IDOCompl- LTR- EmergencyPowerReductionReq-
                         10BitTagReq- OBFF Disabled, EETLPPrefixBlk-
                LnkCap2: Supported Link Speeds: 2.5-32GT/s, Crosslink- Retimer- 2Retimers- DRS-
                LnkCtl2: Target Link Speed: 32GT/s, EnterCompliance- SpeedDis-
                         Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                         Compliance Preset/De-emphasis: -6dB de-emphasis, 0dB preshoot
                LnkSta2: Current De-emphasis Level: -6dB, EqualizationComplete- EqualizationPhase1-
                         EqualizationPhase2- EqualizationPhase3- LinkEqualizationRequest-
                         Retimer- 2Retimers- CrosslinkRes: unsupported, FltMode-
        Capabilities: [100 v1] Device Serial Number 00-00-00-00-00-00-00-01
        Capabilities: [10c v1] Designated Vendor-Specific: Vendor=1e98 ID=0000 Rev=3 Len=60: CXL
                PCIe DVSEC for CXL Devices
                CXLCap: Cache- IO+ Mem+ MemHWInit+ HDMCount 1 Viral-
                CXLCtl: Cache- IO+ Mem+ CacheSFCov 0 CacheSFGran 0 CacheClean- Viral-
                CXLSta: Viral-
                CXLCtl2:        DisableCaching- InitCacheWB&Inval- InitRst- RstMemClrEn- DesiredVolatileHDMStateAfterHotReset-
                CXLSta2:        ResetComplete+ ResetError- PMComplete-
                CXLCap2:        Cache Size Not Reported
                Range1: 0000000000000000-000000000fffffff [size=0x10000000]
                        Valid+ Active+ Type=CDAT Class=CDAT interleave=0 timeout=1s
                Range2: 0000000000000000-ffffffffffffffff [size=0x0]
                        Valid- Active- Type=Volatile Class=DRAM interleave=0 timeout=1s
                CXLCap3:        DefaultVolatile HDM State After:        ColdReset- WarmReset- HotReset- HotResetConfigurability-
        Capabilities: [148 v1] Designated Vendor-Specific: Vendor=1e98 ID=0008 Rev=0 Len=36: CXL
                Register Locator DVSEC
                Block1: BIR: bar0, ID: component registers, offset: 0000000000000000
                Block2: BIR: bar2, ID: CXL device registers, offset: 0000000000000000
        Capabilities: [16c v1] Designated Vendor-Specific: Vendor=1e98 ID=0005 Rev=0 Len=16: CXL
                GPF DVSEC for CXL Devices
                GPF Phase 2 Duration: 3s
                GPF Phase 2 Power: 51mW
        Capabilities: [17c v1] Designated Vendor-Specific: Vendor=1e98 ID=0007 Rev=2 Len=32: CXL
                PCIe DVSEC for Flex Bus Port
                FBCap:  Cache- IO+ Mem+ 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBCtl:  Cache- IO+ Mem- SynHdrByp- DrftBuf- 68BFlit- MltLogDev- RCD- Retimer1- Retimer2- 256BFlit- PBRFlit-
                FBSta:  Cache- IO+ Mem+ SynHdrByp- DrftBuf- 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBModTS:        Received FB Data: 0000ef
                FBCap2: NOPHint-
                FBCtl2: NOPHint+
                FBSta2: NOPHintInfo: 0
        Capabilities: [190 v1] Data Object Exchange
                DOECap: IntSup+
                        IntMsgNum 0
                DOECtl: IntEn-
                DOESta: Busy- IntSta- Error- ObjectReady-
        Capabilities: [200 v2] Advanced Error Reporting
                UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr- BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr+
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr- CorrIntErr- HeaderOF-
                CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+ CorrIntErr+ HeaderOF+
                AERCap: First Error Pointer: 00, ECRCGenCap+ ECRCGenEn- ECRCChkCap+ ECRCChkEn-
                        MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
                HeaderLog: 00000000 00000000 00000000 00000000
        Kernel driver in use: cxl_pci
        Kernel modules: cxl_pci
```

CXL デバイスを確認する。

```sh
cxl list -vvv
```

```json
[
  {
    "bus":"root0",
    "provider":"ACPI.CXL",
    "injectable_protocol_errors":[],
    "nr_dports":1,
    "dports":[
      {
        "dport":"pci0000:0c",
        "alias":"ACPI0016:00",
        "id":12,
        "protocol_injectable":false
      }
    ],
    "ports:root0":[
      {
        "port":"port1",
        "host":"pci0000:0c",
        "depth":1,
        "decoders_committed":0,
        "nr_dports":1,
        "dports":[
          {
            "dport":"0000:0c:00.0",
            "id":0,
            "protocol_injectable":false
          }
        ],
        "endpoints:port1":[
          {
            "endpoint":"endpoint2",
            "host":"mem0",
            "parent_dport":"0000:0c:00.0",
            "depth":2,
            "decoders_committed":0,
            "memdev":{
              "memdev":"mem0",
              "pmem_size":268435456,
              "alert_config":{
                "life_used_prog_warn_threshold_valid":false,
                "dev_over_temperature_prog_warn_threshold_valid":false,
                "dev_under_temperature_prog_warn_threshold_valid":false,
                "corrected_volatile_mem_err_prog_warn_threshold_valid":false,
                "corrected_pmem_err_prog_warn_threshold_valid":false,
                "life_used_prog_warn_threshold_writable":false,
                "dev_over_temperature_prog_warn_threshold_writable":false,
                "dev_under_temperature_prog_warn_threshold_writable":false,
                "corrected_volatile_mem_err_prog_warn_threshold_writable":false,
                "corrected_pmem_err_prog_warn_threshold_writable":false,
                "life_used_crit_alert_threshold":75,
                "life_used_prog_warn_threshold":40,
                "dev_over_temperature_crit_alert_threshold":35,
                "dev_under_temperature_crit_alert_threshold":10,
                "dev_over_temperature_prog_warn_threshold":25,
                "dev_under_temperature_prog_warn_threshold":20,
                "corrected_volatile_mem_err_prog_warn_threshold":0,
                "corrected_pmem_err_prog_warn_threshold":0
              },
              "serial":1,
              "host":"0000:0d:00.0",
              "firmware_version":"BWFW VERSION 00",
              "poison_injectable":true,
              "partition_info":{
                "total_size":268435456,
                "volatile_only_size":0,
                "persistent_only_size":268435456,
                "partition_alignment_size":0
              },
              "firmware":{
                "num_slots":2,
                "active_slot":1,
                "online_activate_capable":true,
                "slot_1_version":"BWFW VERSION 0",
                "fw_update_in_progress":false
              }
            },
            "decoders:endpoint2":[
              {
                "decoder":"decoder2.0",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.1",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.2",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.3",
                "interleave_ways":1,
                "state":"disabled"
              }
            ]
          }
        ],
        "decoders:port1":[
          {
            "decoder":"decoder1.0",
            "interleave_ways":1,
            "state":"disabled",
            "nr_targets":1,
            "targets":[
              {
                "target":"0000:0c:00.0",
                "position":0,
                "id":0
              }
            ]
          }
        ]
      }
    ],
    "decoders:root0":[
      {
        "decoder":"decoder0.0",
        "resource":19595788288,
        "size":4294967296,
        "interleave_ways":1,
        "max_available_extent":4294967296,
        "pmem_capable":true,
        "volatile_capable":true,
        "accelmem_capable":true,
        "qos_class":0,
        "nr_targets":1,
        "targets":[
          {
            "target":"pci0000:0c",
            "alias":"ACPI0016:00",
            "position":0,
            "id":12
          }
        ]
      }
    ]
  }
]
```

NVDIMM デバイスを確認する。

```sh
ndctl list -vvv
```

```json
[
  {
    "provider":"CXL",
    "dev":"ndbus0",
    "dimms":[
      {
        "dev":"nmem0",
        "id":"1",
        "security":"disabled"
      }
    ]
  }
]
```

CEDT テーブルをダンプする。

```sh
cat /sys/firmware/acpi/tables/CEDT > cedt.dat
iasl -d cedt.dat
```

```text
Intel ACPI Component Architecture
ASL+ Optimizing Compiler/Disassembler version 20260408
Copyright (c) 2000 - 2026 Intel Corporation

File appears to be binary: found 80 non-ASCII characters, disassembling
Binary file appears to be a valid ACPI table, disassembling
Input file cedt.dat, Length 0x6C (108) bytes
ACPI: CEDT 0x0000000000000000 00006C (v01 BOCHS  BXPC     00000001 BXPC 00000001)
Acpi Data Table [CEDT] decoded
Formatted output:  cedt.dsl - 2620 bytes
```

CEDT テーブルを確認する。
Window サイズが 4GiB になっている。

```sh
cat cedt.dsl
```

```text
/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (64-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 *
 * Disassembly of cedt.dat
 *
 * ACPI Data Table [CEDT]
 *
 * Format: [HexOffset DecimalOffset ByteLength]  FieldName : FieldValue (in hex)
 */

[000h 0000 004h]                   Signature : "CEDT"    [CXL Early Discovery Table]
[004h 0004 004h]                Table Length : 0000006C
[008h 0008 001h]                    Revision : 01
[009h 0009 001h]                    Checksum : 7D
[00Ah 0010 006h]                      Oem ID : "BOCHS "
[010h 0016 008h]                Oem Table ID : "BXPC    "
[018h 0024 004h]                Oem Revision : 00000001
[01Ch 0028 004h]             Asl Compiler ID : "BXPC"
[020h 0032 004h]       Asl Compiler Revision : 00000001


[024h 0036 001h]               Subtable Type : 00 [CXL Host Bridge Structure]
[025h 0037 001h]                    Reserved : 00
[026h 0038 002h]                      Length : 0020
[028h 0040 004h]      Associated host bridge : 0000000C
[02Ch 0044 004h]       Specification version : 00000001
[030h 0048 004h]                    Reserved : 00000000
[034h 0052 008h]               Register base : 0000000480000000
[03Ch 0060 008h]             Register length : 0000000000010000

[044h 0068 001h]               Subtable Type : 01 [CXL Fixed Memory Window Structure]
[045h 0069 001h]                    Reserved : 00
[046h 0070 002h]                      Length : 0028
[048h 0072 004h]                    Reserved : 00000000
[04Ch 0076 008h]         Window base address : 0000000490000000
[054h 0084 008h]                 Window size : 0000000100000000
[05Ch 0092 001h]          Interleave Members : 00
[05Dh 0093 001h]       Interleave Arithmetic : 00
[05Eh 0094 002h]                    Reserved : 0000
[060h 0096 004h]                 Granularity : 00000000
[064h 0100 002h]                Restrictions : 000F
[066h 0102 002h]                       QtgId : 0000
[068h 0104 004h]                First Target : 0000000C

Raw Table Data: Length 108 (0x6C)

    0000: 43 45 44 54 6C 00 00 00 01 7D 42 4F 43 48 53 20  // CEDTl....}BOCHS
    0010: 42 58 50 43 20 20 20 20 01 00 00 00 42 58 50 43  // BXPC    ....BXPC
    0020: 01 00 00 00 00 00 20 00 0C 00 00 00 01 00 00 00  // ...... .........
    0030: 00 00 00 00 00 00 00 80 04 00 00 00 00 00 01 00  // ................
    0040: 00 00 00 00 01 00 28 00 00 00 00 00 00 00 00 90  // ......(.........
    0050: 04 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00  // ................
    0060: 00 00 00 00 0F 00 00 00 0C 00 00 00              // ............
```

LSA を初期化する。

```sh
ndctl zero-labels nmem0
```

```text
zeroed 1 nmem
```

リージョン(プール)を作成する。

```sh
cxl create-region mem0 -m -d decoder0.0
```

```text
[   82.825895] quadlet-generator[1233]: processing encountered some errors
[  361.350877] cxl region0: Bypassing cpu_cache_invalidate_memregion() for testing!
{
  "region":"region0",
  "resource":"0x490000000",
  "size":"256.00 MiB (268.44 MB)",
  "type":"pmem",
  "interleave_ways":1,
  "interleave_granularity":256,
  "decode_state":"commit",
  "mappings":[
    {
      "position":0,
      "memdev":"mem0",
      "decoder":"decoder2.0"
    }
  ],
  "qos_class_mismatch":true
}
cxl region: cmd_create_region: created 1 region
```

リージョンを確認する。

```sh
ndctl list -vvv
```

```json
[
  {
    "provider":"CXL",
    "dev":"ndbus0",
    "dimms":[
      {
        "dev":"nmem0",
        "id":"1",
        "security":"disabled"
      }
    ],
    "regions":[
      {
        "dev":"region0",
        "size":268435456,
        "align":16777216,
        "available_size":268435456,
        "max_available_extent":268435456,
        "type":"pmem",
        "numa_node":0,
        "target_node":1,
        "iset_id":8589934593,
        "mappings":[
          {
            "dimm":"nmem0",
            "offset":0,
            "length":268435456,
            "position":0
          }
        ],
        "capabilities":[
          {
            "mode":"fsdax",
            "alignments":[
              4096,
              2097152,
              1073741824
            ]
          },
          {
            "mode":"devdax",
            "alignments":[
              4096,
              2097152,
              1073741824
            ]
          }
        ],
        "persistence_domain":"memory_controller",
        "namespaces":[
          {
            "dev":"namespace0.0",
            "mode":"raw",
            "size":0,
            "uuid":"00000000-0000-0000-0000-000000000000",
            "sector_size":512,
            "state":"disabled",
            "numa_node":0,
            "target_node":1
          }
        ]
      }
    ]
  }
]
```

名前空間(パーティション)を作成する。

```sh
ndctl create-namespace -m fsdax
```

```json
{
  "dev":"namespace0.0",
  "mode":"fsdax",
  "map":"dev",
  "size":"250.00 MiB (262.14 MB)",
  "uuid":"9901e05a-edfc-4405-8996-eae1be01d315",
  "sector_size":512,
  "align":2097152,
  "blockdev":"pmem0"
}
```

デバイスを確認する。

```sh
lsblk -OJ /dev/pmem0
```

```json
{
   "blockdevices": [
      {
         "alignment": 0,
         "id-link": "pmem-9901e05a-edfc-4405-8996-eae1be01d315",
         "id": "9901e05a-edfc-4405-8996-eae1be01d315",
         "disc-aln": 0,
         "dax": true,
         "disc-gran": "0B",
         "disk-seq": 6,
         "disc-max": "0B",
         "disc-zero": false,
         "fsavail": null,
         "fsroots": [],
         "fssize": null,
         "fstype": null,
         "fsused": null,
         "fsuse%": null,
         "fsver": null,
         "group": "disk",
         "hctl": null,
         "hotplug": false,
         "kname": "pmem0",
         "label": null,
         "log-sec": 512,
         "maj:min": "259:0",
         "maj": "259",
         "min": "0",
         "min-io": 4096,
         "mode": "brw-rw----",
         "model": null,
         "mq": "1",
         "name": "pmem0",
         "opt-io": 0,
         "owner": "root",
         "partflags": null,
         "partlabel": null,
         "partn": null,
         "parttype": null,
         "parttypename": null,
         "partuuid": null,
         "path": "/dev/pmem0",
         "phy-sec": 4096,
         "pkname": null,
         "pttype": null,
         "ptuuid": null,
         "ra": 128,
         "rand": false,
         "rev": null,
         "rm": false,
         "ro": false,
         "rota": false,
         "rq-size": null,
         "sched": null,
         "serial": null,
         "size": "250M",
         "start": null,
         "state": null,
         "subsystems": "block:nd:cxl:platform",
         "mountpoint": null,
         "mountpoints": [],
         "tran": null,
         "type": "disk",
         "uuid": null,
         "vendor": null,
         "wsame": "0B",
         "wwn": null,
         "zoned": "none",
         "zone-sz": "0B",
         "zone-wgran": "0B",
         "zone-app": "0B",
         "zone-nr": 0,
         "zone-omax": 0,
         "zone-amax": 0
      }
   ]
}
```

ファイルシステムを作成する。

```sh
mkfs -b 4096 -t ext4 /dev/pmem0
```

```text
mke2fs 1.47.3 (8-Jul-2025)
Creating filesystem with 64000 4k blocks and 64000 inodes
Filesystem UUID: 468deb19-7a7f-4ae3-85e0-db0255075c1a
Superblock backups stored on blocks:
        32768

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

マウントする。

```sh
mkdir /mnt/pmem0
mount -o dax /dev/pmem0 /mnt/pmem0/
df -Th /dev/pmem0
```

```text
[  967.068060] EXT4-fs (pmem0): mounted filesystem 468deb19-7a7f-4ae3-85e0-db0255075c1a r/w with ordered data mode. Quota mode: none.
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/pmem0     ext4  219M  152K  201M   1% /mnt/pmem0
```

## 揮発性メモリ

エミュレーション環境を起動する。

- メモリ上に [CXL Type 3](https://github.com/qemu/qemu/commit/e1706ea83da0120be6708b66394ec3a9f3ec48ca) 揮発性メモリとする。
- CXL 対応の [PCIe Expander Bridge](https://github.com/qemu/qemu/commit/4f8db8711cbd27c9acf17e685987e9e74815e087) (pxb-cxl) を作成する。
- [CXL Root Port](https://github.com/qemu/qemu/commit/d86d30192b7bc5a10fa6c82c073f55aea25f9291) (cxl-rp) を作成する。
- [CXL Fixed Memory Windows](https://github.com/qemu/qemu/commit/03b39fcf64bc958e3223e1d696f9de06de904fc6) (CFMW) を作成する。

```sh
qemu-system-x86_64 \
  -drive file=/root/disk.qcow2,format=qcow2,media=disk \
  -m size=4G,slots=8,maxmem=8G \
  -smp cores=2,sockets=1 \
  -machine type=q35,nvdimm=on,cxl=on \
  -net nic \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic \
  -object memory-backend-ram,id=cxl-mem1,share=on,size=256M \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,volatile-memdev=cxl-mem1,id=cxl-vmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G
```

不揮発メモリの場合と同様に必要なソフトウェアをインストールする。

バージョンを確認する。

```sh
uname -a
```

```text
Linux localhost.localdomain 7.0.9-205.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Sat May 23 09:13:54 JST 2026 x86_64 GNU/Linux
```

デバイスを確認する。

```sh
lspci -tv
```

```text
-+-[0000:00]-+-00.0  Intel Corporation 82G33/G31/P35/P31 Express DRAM Controller
 |           +-01.0  Device 1234:1111
 |           +-02.0  Intel Corporation 82574L Gigabit Network Connection
 |           +-03.0  Red Hat, Inc. QEMU PCIe Expander bridge
 |           +-1f.0  Intel Corporation 82801IB (ICH9) LPC Interface Controller
 |           +-1f.2  Intel Corporation 82801IR/IO/IH (ICH9R/DO/DH) 6 port SATA Controller [AHCI mode]
 |           \-1f.3  Intel Corporation 82801I (ICH9 Family) SMBus Controller
 \-[0000:0c]---00.0-[0d]----00.0  Intel Corporation Device 0d93
```

```sh
lspci -vvv
```

```text
[snip]

0d:00.0 CXL: Intel Corporation Device 0d93 (rev 01) (prog-if 10 [CXL Memory Device (CXL 2.0 or later)])
        Subsystem: Red Hat, Inc. Device 1100
        Physical Slot: 2
        Control: I/O+ Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR+ FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
        Latency: 0
        Region 0: Memory at fe800000 (64-bit, non-prefetchable) [size=64K]
        Region 2: Memory at fe810000 (64-bit, non-prefetchable) [size=4K]
        Region 4: Memory at fe811000 (32-bit, non-prefetchable) [size=4K]
        Capabilities: [40] MSI-X: Enable+ Count=8 Masked-
                Vector table: BAR=4 offset=00000000
                PBA: BAR=4 offset=00000800
        Capabilities: [80] Express (v2) Endpoint, IntMsgNum 0
                DevCap: MaxPayload 128 bytes, PhantFunc 0, Latency L0s <64ns, L1 <1us
                        ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset- SlotPowerLimit 0W TEE-IO-
                DevCtl: CorrErr+ NonFatalErr+ FatalErr+ UnsupReq+
                        RlxdOrd- ExtTag- PhantFunc- AuxPwr- NoSnoop-
                        MaxPayload 128 bytes, MaxReadReq 128 bytes
                DevSta: CorrErr- NonFatalErr- FatalErr- UnsupReq- AuxPwr- TransPend-
                LnkCap: Port #0, Speed 32GT/s, Width x16, ASPM L0s, Exit Latency L0s <64ns
                        ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp-
                LnkCtl: ASPM Disabled; RCB 64 bytes, LnkDisable- CommClk-
                        ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt- FltModeDis-
                LnkSta: Speed 32GT/s, Width x16
                        TrErr- Train- SlotClk- DLActive- BWMgmt- ABWMgmt-
                DevCap2: Completion Timeout: Not Supported, TimeoutDis- NROPrPrP- LTR-
                         10BitTagComp- 10BitTagReq- OBFF Not Supported, ExtFmt+ EETLPPrefix+, MaxEETLPPrefixes 4
                         EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                         FRS- TPHComp- ExtTPHComp-
                         AtomicOpsCap: 32bit- 64bit- 128bitCAS-
                DevCtl2: Completion Timeout: 50us to 50ms, TimeoutDis-
                         AtomicOpsCtl: ReqEn-
                         IDOReq- IDOCompl- LTR- EmergencyPowerReductionReq-
                         10BitTagReq- OBFF Disabled, EETLPPrefixBlk-
                LnkCap2: Supported Link Speeds: 2.5-32GT/s, Crosslink- Retimer- 2Retimers- DRS-
                LnkCtl2: Target Link Speed: 32GT/s, EnterCompliance- SpeedDis-
                         Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                         Compliance Preset/De-emphasis: -6dB de-emphasis, 0dB preshoot
                LnkSta2: Current De-emphasis Level: -6dB, EqualizationComplete- EqualizationPhase1-
                         EqualizationPhase2- EqualizationPhase3- LinkEqualizationRequest-
                         Retimer- 2Retimers- CrosslinkRes: unsupported, FltMode-
        Capabilities: [100 v1] Designated Vendor-Specific: Vendor=1e98 ID=0000 Rev=3 Len=60: CXL
                PCIe DVSEC for CXL Devices
                CXLCap: Cache- IO+ Mem+ MemHWInit+ HDMCount 1 Viral-
                CXLCtl: Cache- IO+ Mem+ CacheSFCov 0 CacheSFGran 0 CacheClean- Viral-
                CXLSta: Viral-
                CXLCtl2:        DisableCaching- InitCacheWB&Inval- InitRst- RstMemClrEn- DesiredVolatileHDMStateAfterHotReset-
                CXLSta2:        ResetComplete+ ResetError- PMComplete-
                CXLCap2:        Cache Size Not Reported
                Range1: 0000000000000000-000000000fffffff [size=0x10000000]
                        Valid+ Active+ Type=CDAT Class=CDAT interleave=0 timeout=1s
                Range2: 0000000000000000-ffffffffffffffff [size=0x0]
                        Valid- Active- Type=Volatile Class=DRAM interleave=0 timeout=1s
                CXLCap3:        DefaultVolatile HDM State After:        ColdReset- WarmReset- HotReset- HotResetConfigurability-
        Capabilities: [13c v1] Designated Vendor-Specific: Vendor=1e98 ID=0008 Rev=0 Len=36: CXL
                Register Locator DVSEC
                Block1: BIR: bar0, ID: component registers, offset: 0000000000000000
                Block2: BIR: bar2, ID: CXL device registers, offset: 0000000000000000
        Capabilities: [160 v1] Designated Vendor-Specific: Vendor=1e98 ID=0005 Rev=0 Len=16: CXL
                GPF DVSEC for CXL Devices
                GPF Phase 2 Duration: 3s
                GPF Phase 2 Power: 51mW
        Capabilities: [170 v1] Designated Vendor-Specific: Vendor=1e98 ID=0007 Rev=2 Len=32: CXL
                PCIe DVSEC for Flex Bus Port
                FBCap:  Cache- IO+ Mem+ 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBCtl:  Cache- IO+ Mem- SynHdrByp- DrftBuf- 68BFlit- MltLogDev- RCD- Retimer1- Retimer2- 256BFlit- PBRFlit-
                FBSta:  Cache- IO+ Mem+ SynHdrByp- DrftBuf- 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBModTS:        Received FB Data: 0000ef
                FBCap2: NOPHint-
                FBCtl2: NOPHint-
                FBSta2: NOPHintInfo: 0
        Capabilities: [190 v1] Data Object Exchange
                DOECap: IntSup+
                        IntMsgNum 0
                DOECtl: IntEn-
                DOESta: Busy- IntSta- Error- ObjectReady-
        Capabilities: [200 v2] Advanced Error Reporting
                UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr- BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr+
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr- CorrIntErr- HeaderOF-
                CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+ CorrIntErr+ HeaderOF+
                AERCap: First Error Pointer: 00, ECRCGenCap+ ECRCGenEn- ECRCChkCap+ ECRCChkEn-
                        MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
                HeaderLog: 00000000 00000000 00000000 00000000
        Kernel driver in use: cxl_pci
        Kernel modules: cxl_pci
```

CXL デバイスを確認する。

```sh
cxl list -vvv
```

```json
[
  {
    "bus":"root0",
    "provider":"ACPI.CXL",
    "injectable_protocol_errors":[],
    "nr_dports":1,
    "dports":[
      {
        "dport":"pci0000:0c",
        "alias":"ACPI0016:00",
        "id":12,
        "protocol_injectable":false
      }
    ],
    "ports:root0":[
      {
        "port":"port1",
        "host":"pci0000:0c",
        "depth":1,
        "decoders_committed":0,
        "nr_dports":1,
        "dports":[
          {
            "dport":"0000:0c:00.0",
            "id":0,
            "protocol_injectable":false
          }
        ],
        "endpoints:port1":[
          {
            "endpoint":"endpoint2",
            "host":"mem0",
            "parent_dport":"0000:0c:00.0",
            "depth":2,
            "decoders_committed":0,
            "memdev":{
              "memdev":"mem0",
              "ram_size":268435456,
              "alert_config":{
                "life_used_prog_warn_threshold_valid":false,
                "dev_over_temperature_prog_warn_threshold_valid":false,
                "dev_under_temperature_prog_warn_threshold_valid":false,
                "corrected_volatile_mem_err_prog_warn_threshold_valid":false,
                "corrected_pmem_err_prog_warn_threshold_valid":false,
                "life_used_prog_warn_threshold_writable":false,
                "dev_over_temperature_prog_warn_threshold_writable":false,
                "dev_under_temperature_prog_warn_threshold_writable":false,
                "corrected_volatile_mem_err_prog_warn_threshold_writable":false,
                "corrected_pmem_err_prog_warn_threshold_writable":false,
                "life_used_crit_alert_threshold":75,
                "life_used_prog_warn_threshold":40,
                "dev_over_temperature_crit_alert_threshold":35,
                "dev_under_temperature_crit_alert_threshold":10,
                "dev_over_temperature_prog_warn_threshold":25,
                "dev_under_temperature_prog_warn_threshold":20,
                "corrected_volatile_mem_err_prog_warn_threshold":0,
                "corrected_pmem_err_prog_warn_threshold":0
              },
              "serial":0,
              "host":"0000:0d:00.0",
              "firmware_version":"BWFW VERSION 00",
              "poison_injectable":true,
              "partition_info":{
                "total_size":268435456,
                "volatile_only_size":268435456,
                "persistent_only_size":0,
                "partition_alignment_size":0
              },
              "firmware":{
                "num_slots":2,
                "active_slot":1,
                "online_activate_capable":true,
                "slot_1_version":"BWFW VERSION 0",
                "fw_update_in_progress":false
              }
            },
            "decoders:endpoint2":[
              {
                "decoder":"decoder2.0",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.1",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.2",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.3",
                "interleave_ways":1,
                "state":"disabled"
              }
            ]
          }
        ],
        "decoders:port1":[
          {
            "decoder":"decoder1.0",
            "interleave_ways":1,
            "state":"disabled",
            "nr_targets":1,
            "targets":[
              {
                "target":"0000:0c:00.0",
                "position":0,
                "id":0
              }
            ]
          }
        ]
      }
    ],
    "decoders:root0":[
      {
        "decoder":"decoder0.0",
        "resource":19595788288,
        "size":4294967296,
        "interleave_ways":1,
        "max_available_extent":4294967296,
        "pmem_capable":true,
        "volatile_capable":true,
        "accelmem_capable":true,
        "qos_class":0,
        "nr_targets":1,
        "targets":[
          {
            "target":"pci0000:0c",
            "alias":"ACPI0016:00",
            "position":0,
            "id":12
          }
        ]
      }
    ]
  }
]
```

リージョンを作成する。

```sh
cxl create-region mem0 -m -d decoder0.0 -t ram
```

```text
[  289.732434] quadlet-generator[1263]: processing encountered some errors
[  601.275453] cxl region0: Bypassing cpu_cache_invalidate_memregion() for testing!
{
  "region":"region0",
  "resource":"0x490000000",
  "size":"256.00 MiB (268.44 MB)",
  "type":"ram",
  "interleave_ways":1,
  "interleave_granularity":256,
  "decode_state":"commit",
  "mappings":[
    {
      "position":0,
      "memdev":"mem0",
      "decoder":"decoder2.0"
    }
  ],
  "qos_class_mismatch":true
}
cxl region: cmd_create_region: created 1 region
[  601.451913] Fallback order for Node 1: 0
[  601.454632] Built 1 zonelists, mobility grouping on.  Total pages: 973789
[  601.455952] Policy zone: Normal
[  601.476713] Fallback order for Node 0: 0 1
[  601.476828] Fallback order for Node 1: 1 0
[  601.478426] Built 2 zonelists, mobility grouping on.  Total pages: 1006557
[  601.479450] Policy zone: Normal
[  601.518534] Demotion targets for Node 0: preferred: 1, fallback: 1
[  601.519869] Demotion targets for Node 1: null
```

コマンドの内部で下記が実行される。

リージョンを作成する。

```sh
echo region0 > /sys/bus/cxl/devices/decoder0.0/create_ram_region
```

粒度を設定する。

```sh
echo 256 > /sys/bus/cxl/devices/decoder0.0/region0/interleave_granularity
```

インターリブ数を設定する。

```sh
echo 1 > /sys/bus/cxl/devices/decoder0.0/region0/interleave_ways
```

サイズを設定する。

```sh
echo 268435456 > /sys/bus/cxl/devices/decoder0.0/region0/size
```

エンドポイントデコーダを設定する。

```sh
echo 0 > /sys/bus/cxl/devices/decoder2.0/dpa_size
echo ram > /sys/bus/cxl/devices/decoder2.0/mode
echo 268435456 > /sys/bus/cxl/devices/decoder2.0/dpa_size
```

ターゲットを設定する。

```sh
echo decoder2.0 > /sys/bus/cxl/devices/decoder0.0/region0/target0
```

設定を適用する。

```sh
echo 1 > /sys/bus/cxl/devices/decoder0.0/region0/commit
```

```text
[  636.652790] cxl region0: Bypassing cpu_cache_invalidate_memregion() for testing!
```

バインドする。

```sh
echo region0 > /sys/bus/cxl/drivers/cxl_region/bind
```

NUMA ノードが作成されシステムメモリに追加される。

```text
[  750.986486] Built 1 zonelists, mobility grouping on.  Total pages: 973788
[  750.987984] Policy zone: Normal
[  751.009549] Fallback order for Node 0: 0 1
[  751.009625] Fallback order for Node 1: 1 0
[  751.009640] Built 2 zonelists, mobility grouping on.  Total pages: 1006556
[  751.015492] Policy zone: Normal
[  751.044897] Demotion targets for Node 0: preferred: 1, fallback: 1
[  751.046194] Demotion targets for Node 1: null
```

リージョンを確認する。

```sh
daxctl list -DRM
```

```json
[
  {
    "path":"\/platform\/ACPI0017:00\/root0\/decoder0.0\/region0\/dax_region0",
    "id":0,
    "size":268435456,
    "align":2097152,
    "devices":[
      {
        "chardev":"dax0.0",
        "size":268435456,
        "target_node":1,
        "align":2097152,
        "mode":"system-ram",
        "online_memblocks":2,
        "total_memblocks":2,
        "movable":false,
        "mappings":[
          {
            "page_offset":0,
            "start":19595788288,
            "end":19864223743,
            "size":268435456
          }
        ]
      }
    ]
  }
]
```

メモリを確認する。CFMW が示すアドレス (0x0000000490000000) が追加されている。

```sh
lsmem
```

```text
RANGE                                  SIZE  STATE REMOVABLE   BLOCK
0x0000000000000000-0x000000007fffffff    2G online       yes    0-15
0x0000000100000000-0x000000017fffffff    2G online       yes   32-47
0x0000000490000000-0x000000049fffffff  256M online       yes 146-147

Memory block size:                128M
Total online memory:              4.3G
Total offline memory:               0B
```

NUMA ノードを確認する。イニシエータなしノードがある。

```sh
numactl -H
```

```text
available: 2 nodes (0-1)
node 0 cpus: 0 1
node 0 size: 3902 MB
node 0 free: 2853 MB
node 1 cpus:
node 1 size: 256 MB
node 1 free: 255 MB
node distances:
node     0    1
   0:   10   20
   1:   20   10
```

## Dynamic Capacity Device

エミュレーション環境を起動する。

- メモリ上に [CXL Type 3](https://github.com/qemu/qemu/commit/90de94612bb568117e038c6ce9edd35d17d239f9) DCD とする。
- DCD は 2 リージョンとする。サイズは 256M x 2 リージョンの倍数として 1G とする。
- CXL 対応の [PCIe Expander Bridge](https://github.com/qemu/qemu/commit/4f8db8711cbd27c9acf17e685987e9e74815e087) (pxb-cxl) を作成する。
- [CXL Root Port](https://github.com/qemu/qemu/commit/d86d30192b7bc5a10fa6c82c073f55aea25f9291) (cxl-rp) を作成する。
- [CXL Fixed Memory Windows](https://github.com/qemu/qemu/commit/03b39fcf64bc958e3223e1d696f9de06de904fc6) (CFMW) を作成する。

```sh
qemu-system-x86_64 \
  -drive file=/root/disk.qcow2,format=qcow2,media=disk \
  -m size=4G,slots=8,maxmem=8G \
  -smp cores=2,sockets=1 \
  -machine type=q35,nvdimm=on,cxl=on \
  -net nic \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic \
  -qmp unix:/tmp/qmp.sock,server=on,wait=off \
  -object memory-backend-ram,id=cxl-mem1,share=on,size=1G \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,volatile-dc-memdev=cxl-mem1,num-dc-regions=2,id=cxl-dmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G
```

不揮発メモリの場合と同様に必要なソフトウェアをインストールする。

バージョンを確認する。

```sh
uname -a
```

```text
Linux localhost.localdomain 7.0.9-205.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Sat May 23 09:13:54 JST 2026 x86_64 GNU/Linux
```

デバイスを確認する。

```sh
lspci -tv
```

```text
-+-[0000:00]-+-00.0  Intel Corporation 82G33/G31/P35/P31 Express DRAM Controller
 |           +-01.0  Device 1234:1111
 |           +-02.0  Intel Corporation 82574L Gigabit Network Connection
 |           +-03.0  Red Hat, Inc. QEMU PCIe Expander bridge
 |           +-1f.0  Intel Corporation 82801IB (ICH9) LPC Interface Controller
 |           +-1f.2  Intel Corporation 82801IR/IO/IH (ICH9R/DO/DH) 6 port SATA Controller [AHCI mode]
 |           \-1f.3  Intel Corporation 82801I (ICH9 Family) SMBus Controller
 \-[0000:0c]---00.0-[0d]----00.0  Intel Corporation Device 0d93
```

```sh
lspci -vvv
```

```text
[snip]

0d:00.0 CXL: Intel Corporation Device 0d93 (rev 01) (prog-if 10 [CXL Memory Device (CXL 2.0 or later)])
        Subsystem: Red Hat, Inc. Device 1100
        Physical Slot: 2
        Control: I/O+ Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR+ FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
        Latency: 0
        Region 0: Memory at fe800000 (64-bit, non-prefetchable) [size=64K]
        Region 2: Memory at fe810000 (64-bit, non-prefetchable) [size=4K]
        Region 4: Memory at fe811000 (32-bit, non-prefetchable) [size=4K]
        Capabilities: [40] MSI-X: Enable+ Count=8 Masked-
                Vector table: BAR=4 offset=00000000
                PBA: BAR=4 offset=00000800
        Capabilities: [80] Express (v2) Endpoint, IntMsgNum 0
                DevCap: MaxPayload 128 bytes, PhantFunc 0, Latency L0s <64ns, L1 <1us
                        ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset- SlotPowerLimit 0W TEE-IO-
                DevCtl: CorrErr+ NonFatalErr+ FatalErr+ UnsupReq+
                        RlxdOrd- ExtTag- PhantFunc- AuxPwr- NoSnoop-
                        MaxPayload 128 bytes, MaxReadReq 128 bytes
                DevSta: CorrErr- NonFatalErr- FatalErr- UnsupReq- AuxPwr- TransPend-
                LnkCap: Port #0, Speed 32GT/s, Width x16, ASPM L0s, Exit Latency L0s <64ns
                        ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp-
                LnkCtl: ASPM Disabled; RCB 64 bytes, LnkDisable- CommClk-
                        ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt- FltModeDis-
                LnkSta: Speed 32GT/s, Width x16
                        TrErr- Train- SlotClk- DLActive- BWMgmt- ABWMgmt-
                DevCap2: Completion Timeout: Not Supported, TimeoutDis- NROPrPrP- LTR-
                         10BitTagComp- 10BitTagReq- OBFF Not Supported, ExtFmt+ EETLPPrefix+, MaxEETLPPrefixes 4
                         EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                         FRS- TPHComp- ExtTPHComp-
                         AtomicOpsCap: 32bit- 64bit- 128bitCAS-
                DevCtl2: Completion Timeout: 50us to 50ms, TimeoutDis-
                         AtomicOpsCtl: ReqEn-
                         IDOReq- IDOCompl- LTR- EmergencyPowerReductionReq-
                         10BitTagReq- OBFF Disabled, EETLPPrefixBlk-
                LnkCap2: Supported Link Speeds: 2.5-32GT/s, Crosslink- Retimer- 2Retimers- DRS-
                LnkCtl2: Target Link Speed: 32GT/s, EnterCompliance- SpeedDis-
                         Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                         Compliance Preset/De-emphasis: -6dB de-emphasis, 0dB preshoot
                LnkSta2: Current De-emphasis Level: -6dB, EqualizationComplete- EqualizationPhase1-
                         EqualizationPhase2- EqualizationPhase3- LinkEqualizationRequest-
                         Retimer- 2Retimers- CrosslinkRes: unsupported, FltMode-
        Capabilities: [100 v1] Designated Vendor-Specific: Vendor=1e98 ID=0000 Rev=3 Len=60: CXL
                PCIe DVSEC for CXL Devices
                CXLCap: Cache- IO+ Mem+ MemHWInit+ HDMCount 1 Viral-
                CXLCtl: Cache- IO+ Mem+ CacheSFCov 0 CacheSFGran 0 CacheClean- Viral-
                CXLSta: Viral-
                CXLCtl2:        DisableCaching- InitCacheWB&Inval- InitRst- RstMemClrEn- DesiredVolatileHDMStateAfterHotReset-
                CXLSta2:        ResetComplete+ ResetError- PMComplete-
                CXLCap2:        Cache Size Not Reported
                Range1: 0000000000000000-ffffffffffffffff [size=0x0]
                        Valid+ Active+ Type=CDAT Class=CDAT interleave=0 timeout=1s
                Range2: 0000000000000000-ffffffffffffffff [size=0x0]
                        Valid- Active- Type=Volatile Class=DRAM interleave=0 timeout=1s
                CXLCap3:        DefaultVolatile HDM State After:        ColdReset- WarmReset- HotReset- HotResetConfigurability-
        Capabilities: [13c v1] Designated Vendor-Specific: Vendor=1e98 ID=0008 Rev=0 Len=36: CXL
                Register Locator DVSEC
                Block1: BIR: bar0, ID: component registers, offset: 0000000000000000
                Block2: BIR: bar2, ID: CXL device registers, offset: 0000000000000000
        Capabilities: [160 v1] Designated Vendor-Specific: Vendor=1e98 ID=0005 Rev=0 Len=16: CXL
                GPF DVSEC for CXL Devices
                GPF Phase 2 Duration: 3s
                GPF Phase 2 Power: 51mW
        Capabilities: [170 v1] Designated Vendor-Specific: Vendor=1e98 ID=0007 Rev=2 Len=32: CXL
                PCIe DVSEC for Flex Bus Port
                FBCap:  Cache- IO+ Mem+ 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBCtl:  Cache- IO+ Mem- SynHdrByp- DrftBuf- 68BFlit- MltLogDev- RCD- Retimer1- Retimer2- 256BFlit- PBRFlit-
                FBSta:  Cache- IO+ Mem+ SynHdrByp- DrftBuf- 68BFlit+ MltLogDev- 256BFlit- PBRFlit-
                FBModTS:        Received FB Data: 0000ef
                FBCap2: NOPHint-
                FBCtl2: NOPHint-
                FBSta2: NOPHintInfo: 0
        Capabilities: [190 v1] Data Object Exchange
                DOECap: IntSup+
                        IntMsgNum 0
                DOECtl: IntEn-
                DOESta: Busy- IntSta- Error- ObjectReady-
        Capabilities: [200 v2] Advanced Error Reporting
                UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr- BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP-
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr+
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+
                        ECRC- UnsupReq- ACSViol- UncorrIntErr+ BlockedTLP- AtomicOpBlocked- TLPBlockedErr-
                        PoisonTLPBlocked- DMWrReqBlocked- IDECheck- MisIDETLP- PCRC_CHECK- TLPXlatBlocked-
                CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr- CorrIntErr- HeaderOF-
                CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+ CorrIntErr+ HeaderOF+
                AERCap: First Error Pointer: 00, ECRCGenCap+ ECRCGenEn- ECRCChkCap+ ECRCChkEn-
                        MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
                HeaderLog: 00000000 00000000 00000000 00000000
        Kernel driver in use: cxl_pci
        Kernel modules: cxl_pci
```

CXL デバイスを確認する。

```sh
cxl list -vvv
```

```json
[
  {
    "bus":"root0",
    "provider":"ACPI.CXL",
    "injectable_protocol_errors":[],
    "nr_dports":1,
    "dports":[
      {
        "dport":"pci0000:0c",
        "alias":"ACPI0016:00",
        "id":12,
        "protocol_injectable":false
      }
    ],
    "ports:root0":[
      {
        "port":"port1",
        "host":"pci0000:0c",
        "depth":1,
        "decoders_committed":0,
        "nr_dports":1,
        "dports":[
          {
            "dport":"0000:0c:00.0",
            "id":0,
            "protocol_injectable":false
          }
        ],
        "endpoints:port1":[
          {
            "endpoint":"endpoint2",
            "host":"mem0",
            "parent_dport":"0000:0c:00.0",
            "depth":2,
            "decoders_committed":0,
            "memdev":{
              "memdev":"mem0",
              "ram_size":1,
              "ram_qos_class":0,
              "alert_config":{
                "life_used_prog_warn_threshold_valid":false,
                "dev_over_temperature_prog_warn_threshold_valid":false,
                "dev_under_temperature_prog_warn_threshold_valid":false,
                "corrected_volatile_mem_err_prog_warn_threshold_valid":false,
                "corrected_pmem_err_prog_warn_threshold_valid":false,
                "life_used_prog_warn_threshold_writable":false,
                "dev_over_temperature_prog_warn_threshold_writable":false,
                "dev_under_temperature_prog_warn_threshold_writable":false,
                "corrected_volatile_mem_err_prog_warn_threshold_writable":false,
                "corrected_pmem_err_prog_warn_threshold_writable":false,
                "life_used_crit_alert_threshold":75,
                "life_used_prog_warn_threshold":40,
                "dev_over_temperature_crit_alert_threshold":35,
                "dev_under_temperature_crit_alert_threshold":10,
                "dev_over_temperature_prog_warn_threshold":25,
                "dev_under_temperature_prog_warn_threshold":20,
                "corrected_volatile_mem_err_prog_warn_threshold":0,
                "corrected_pmem_err_prog_warn_threshold":0
              },
              "serial":0,
              "host":"0000:0d:00.0",
              "firmware_version":"BWFW VERSION 00",
              "poison_injectable":true,
              "partition_info":{
                "total_size":0,
                "volatile_only_size":0,
                "persistent_only_size":0,
                "partition_alignment_size":0
              },
              "firmware":{
                "num_slots":2,
                "active_slot":1,
                "online_activate_capable":true,
                "slot_1_version":"BWFW VERSION 0",
                "fw_update_in_progress":false
              }
            },
            "decoders:endpoint2":[
              {
                "decoder":"decoder2.0",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.1",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.2",
                "interleave_ways":1,
                "state":"disabled"
              },
              {
                "decoder":"decoder2.3",
                "interleave_ways":1,
                "state":"disabled"
              }
            ]
          }
        ],
        "decoders:port1":[
          {
            "decoder":"decoder1.0",
            "interleave_ways":1,
            "state":"disabled",
            "nr_targets":1,
            "targets":[
              {
                "target":"0000:0c:00.0",
                "position":0,
                "id":0
              }
            ]
          }
        ]
      }
    ],
    "decoders:root0":[
      {
        "decoder":"decoder0.0",
        "resource":19595788288,
        "size":4294967296,
        "interleave_ways":1,
        "max_available_extent":4294967296,
        "pmem_capable":true,
        "volatile_capable":true,
        "accelmem_capable":true,
        "qos_class":0,
        "nr_targets":1,
        "targets":[
          {
            "target":"pci0000:0c",
            "alias":"ACPI0016:00",
            "position":0,
            "id":12
          }
        ]
      }
    ]
  }
]
```

QEMU ホストでエクステントを追加する。

```sh
socat UNIX-CONNECT:/tmp/qmp.sock STDIO
```

```json
{ "execute": "qmp_capabilities" }
{"return": {}}

{ "execute": "cxl-add-dynamic-capacity",
  "arguments": {
    "path": "/machine/peripheral/cxl-dmem0",
    "host-id": 0,
    "selection-policy": "prescriptive",
    "region": 0,
    "extents": [
      {
        "offset": 0,
        "len": 134217728
      }
    ]
  }
}
{"return": {}}
```

リージョンが作成できない。

## 参照

- [Compute Express Link](https://www.qemu.org/docs/master/system/devices/cxl.html)
- [Building a Custom Kernel](https://docs.fedoraproject.org/en-US/quick-docs/kernel-build-custom/)
  - [Customizing kernel configuration](https://discussion.fedoraproject.org/t/customizing-kernel-configuration/122909/2)
- [QMP Index](https://www.qemu.org/docs/master/qapi-qmp-index.html)
