# foji-bsd

Custom FreeBSD ports tree and local package repository builder.

## Local QEMU builder

The repository is built locally in a persistent FreeBSD QEMU VM and the finished
flat pkg repository can be uploaded to GitHub Releases. GitHub is only source
control and release hosting; poudriere state lives under a configurable forge
directory outside this repository.

Default aarch64 build:

```sh
export PKG_REPO_SIGNING_KEY_B64="$(base64 -w0 pkg.key)"
REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod" \
PUBLISH=yes \
scripts/local-qemu-build.sh all
```

Useful knobs:

```sh
FOJI_FORGE_DIR=~/devel/forge
FOJI_BUILDER_ARCH=aarch64
FOJI_SSH_PUBLIC_KEY=~/.ssh/vms.pub
FOJI_SSH_PRIVATE_KEY=~/.ssh/vms
FOJI_SSH_PORT=2222
FOJI_VM_DISK_SIZE=64G
REQUESTED_PORTS=auto
PUBLISH=no
```

Host packages observed on the current Artix/CachyOS-style builder:

```sh
pacman -S qemu-full edk2-ovmf edk2-aarch64 cdrtools openssh rsync github-cli curl xz
```

The aarch64 VM specifically needs `edk2-aarch64`. The similarly named
`qemu-system-arm-firmware` package provides `/usr/share/qemu/edk2-arm-code.fd`,
but that firmware targets armv7. With that wrong firmware, QEMU starts and the
host SSH forward opens, but the guest does not boot correctly: the qcow2 overlay
barely changes, serial output stays empty, and SSH connections time out during
banner exchange.

The script expects:

- amd64 firmware at `/usr/share/edk2/x64/OVMF_CODE.4m.fd` and
  `/usr/share/edk2/x64/OVMF_VARS.4m.fd`.
- aarch64 firmware at `/usr/share/edk2/aarch64/QEMU_EFI.fd` and
  `/usr/share/edk2/aarch64/QEMU_VARS.fd`.
- `genisoimage` from `cdrtools` to create the NoCloud `cidata` ISO consumed by
  FreeBSD `nuageinit`.
- An SSH keypair for the builder user; by default `~/.ssh/vms` and
  `~/.ssh/vms.pub`.

FreeBSD cloud images do not include `rsync`; the host script bootstraps `pkg`
and installs `rsync` in the guest before the first repository sync. The full
poudriere prerequisite set is then managed by `scripts/build-poudriere-repo.sh`
inside the VM.

The upstream cloud-init raw images are intentionally small. The aarch64 ZFS
image used here is about 6 GiB, which is not enough for poudriere to extract
`base.txz` and `src.txz` for a jail. Fresh overlays are resized to
`FOJI_VM_DISK_SIZE`, defaulting to `64G`, before first boot so the FreeBSD grow
step expands the root partition and ZFS pool into usable builder space.

The script downloads the official FreeBSD `BASIC-CLOUDINIT-zfs` image for the
selected architecture, creates a persistent qcow2 overlay with a relative
backing path, creates a NoCloud seed ISO, starts QEMU with host port forwarding,
syncs this ports tree into the VM with rsync, runs poudriere there, copies
`repo-output` back, and optionally uploads release assets with `gh`.

The release URL remains directly usable as a pkg repository URL:

```conf
foji: {
  url: "https://github.com/hazayan/foji-bsd/releases/download/repo-FreeBSD:15:aarch64",
  mirror_type: "none",
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/pkg/keys/foji.pub",
  enabled: yes
}
```
