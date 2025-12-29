# Windows の無人セットアップ

KVM に Windows ゲスト OS を無人セッツアップする。

応答ファイル(*unattend.xml*)をファイル名 *Autounattend.xml* で ISO ファイルを作成する。

```sh
mkisofs -J -o /mnt/unattend.iso Autounattend.xml
```

[virtio-win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/)
の ISO ファイルを用意する。

インストール先のディスクを用意する。

```sh
virsh vol-create-as default win11.qcow2 128GiB --format qcow2
```

Windows のインストール媒体、応答ファイル、virtio-win をマウントして仮想マシンを作成する。

```sh
virt-install \
    --name win11 \
    --vcpu 4 \
    --cpu host-passthrough \
    --memory 8192 \
    --os-variant win11 \
    --disk /var/lib/libvirt/images/win11.qcow2,bus=virtio \
    --disk /mnt/unattend.iso,device=cdrom \
    --disk /mnt/virtio-win-0.1.262.iso,device=cdrom \
    --network network=public,model=virtio \
    --network network=private,model=virtio \
    --graphics vnc,listen=0.0.0.0 \
    --virt-type kvm \
    --cdrom /mnt/Windows11.iso \
    --noautoconsole
```

TODO:

- ISOブート時の「Press any key to ...」
- インストール後の「国または地域はこれでよろしいですか？」
- インストール後の「これは正しいキーボードレイアウトまたは入力方式ですか？」
- インストール後の「2つめのキーボードレイアウトを追加しますか？」
