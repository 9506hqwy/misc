# Linux キックスタートインストール

KVM に Linux ゲスト OS を自動インストールする。

インストール先のディスクを用意する。

```sh
virsh vol-create-as default linux.qcow2 64GiB --format qcow2
```

`--initrd-inject` にキックスタートファイル *ks.cfg* を指定して仮想マシンを作成する。

```sh
virt-install \
    --name linux \
    --vcpu 4 \
    --cpu host-passthrough \
    --memory 8192 \
    --os-variant centos-stream9 \
    --disk /var/lib/libvirt/images/linux.qcow2,bus=virtio \
    --network network=public,model=virtio \
    --network network=private,model=virtio \
    --graphics vnc,listen=0.0.0.0 \
    --virt-type kvm \
    --location /mnt/CentOS-Stream-9-20240923.0-x86_64-dvd1.iso \
    --initrd-inject /root/workspace/ks.cfg \
    --extra-args="inst.ks=file:/ks.cfg console=ttyS0" \
    --noautoconsole
```
