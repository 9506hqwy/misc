# Compute Express Link

## QEMU を利用したエミュレーション

### ホスト環境の構築

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

### ゲスト環境の構築

Fedora の KVM ゲスト用のイメージを拡張しておく。

```sh
qemu-img resize disk.qcow2 +30G
```

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
  -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G
```

※ LSA は NVDIMM のメタデータを保存する領域。

バージョンを確認する。

```sh
uname -a
```

```text
Linux localhost.localdomain 7.0.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri May 15 14:03:46 UTC 2026 x86_64 GNU/Linux
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
                CXLCtl: Cache- IO+ Mem- CacheSFCov 0 CacheSFGran 0 CacheClean- Viral-
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

CXL コマンドをインストールする。

```sh
dnf install cxl-cli　ndctl
cxl version
```

```text
84
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
              "serial":0,
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
        "id":"0",
        "security":"disabled"
      }
    ]
  }
]
```

ACPI ツールをインストールする。

```sh
dnf install acpica-tools
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

## 参照

- [Compute Express Link](https://www.qemu.org/docs/master/system/devices/cxl.html)
