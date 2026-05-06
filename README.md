# foji-bsd

Custom FreeBSD ports tree and local package repository builder.

Porting conventions for custom ports live in [PORTING.md](PORTING.md).

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
pacman -S qemu-full edk2-ovmf edk2-aarch64 cdrtools openssh openbsd-netcat rsync github-cli curl xz
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
- `nc` from `openbsd-netcat`; the local host script uses it while waiting for
  guest SSH to become reachable.
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

On aarch64 the local builder defaults to 2 vCPUs and 4096 MiB of RAM. Earlier
8 GiB runs on a 16 GiB workstation were OOM-killed by the Linux host while
poudriere processed package metadata. Increase `FOJI_VM_MEM` only on a builder
with enough free memory.

On Linux hosts, active VirtualBox VMs can prevent QEMU from creating a KVM VM.
The observed failure was `ioctl(KVM_CREATE_VM) failed: Input/output error` with
`kvm: enabling virtualization on CPU0 failed` in the kernel log. Shut down
VirtualBox guests before starting the local QEMU builder.

The local builder currently defaults to FreeBSD's `quarterly` package branch
and the matching `2026Q2` ports branch. Each architecture may also apply a
temporary `PORTS_REF` pin selected to match the currently published FreeBSD 15
package set. This lets poudriere fetch large build dependencies such as
`lang/rust` as binary packages instead of building them from source. The clean
aarch64 validation run for `REQUESTED_PORTS=kunci` built `ports-mgmt/pkg` and
`sysutils/kunci`, fetched the rest of the dependency closure, and produced a
239 MiB flat repository under `repo-output/FreeBSD:15:aarch64`.

An amd64 relocation smoke run on `altair` with `FOJI_FORGE_DIR=/data/workspace/forge`,
`FOJI_BUILD_PROFILE=kunci`, and `PUBLISH=no` completed the full local cycle:
KVM boot, rsync into the guest, poudriere build, signed flat repository
creation, and fetch back to the host. That first-run path created the poudriere
jail from binary release sets and applied `freebsd-update`; it did not compile
FreeBSD base.

For GitHub release publication, prefer filtering the exported repository to
custom runtime packages:

```sh
FOJI_BUILD_PROFILE=kunci
```

The complete poudriere output is useful for diagnostics, but upstream package
filenames may contain commas for epochs. GitHub release assets normalize those
commas, which breaks pkg repository metadata for those upstream packages. The
custom `sysutils/kunci` package has only FreeBSD base shared-library runtime
requirements, so it can be published by itself while consumers keep the normal
FreeBSD repositories enabled.

The `kunci` profile expands to:

```sh
REQUESTED_PORTS=kunci
REPO_PACKAGE_ORIGINS="sysutils/kunci"
```

For amd64 sysbsd installs, build the bootloader repository profile:

```sh
FOJI_BUILDER_ARCH=amd64
FOJI_BUILD_PROFILE=sysbsd-amd64
```

That profile expands to:

```sh
REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod"
REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod"
```

`zhamel` and `zhamel-zfskey-kmod` are amd64-only ports, so the profile refuses
to run on non-amd64 builders.

For the complete amd64 repository, including sysbsd boot packages and Manticore
Search, build the full amd64 profile:

```sh
FOJI_BUILDER_ARCH=amd64
FOJI_BUILD_PROFILE=foji-amd64
```

That profile expands to:

```sh
REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod manticore nomad-pot-driver knox"
REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod databases/manticore sysutils/nomad-pot-driver security/knox"
```

For amd64 server nodes that need Manticore Search, build the manticore profile:

```sh
FOJI_BUILDER_ARCH=amd64
FOJI_BUILD_PROFILE=manticore-amd64
```

That profile expands to:

```sh
REQUESTED_PORTS="manticore"
REPO_PACKAGE_ORIGINS="databases/manticore"
```

`databases/manticore` is amd64-only and intentionally excluded from the
aarch64 build path.

On altair-class builder hardware, override the conservative amd64 VM size:

```sh
FOJI_VM_CPUS=12
FOJI_VM_MEM=24576
```

The default amd64 VM size is still 4 vCPUs and 8192 MiB so the script remains
usable on smaller workstations.

`sysutils/zhamel` intentionally uses the official Rust standalone
`rust-<version>-x86_64-unknown-freebsd` toolchain plus the matching
`rust-std-<version>-x86_64-unknown-uefi` component, both as distfiles installed
into a private build sysroot. Do not invoke `rustup toolchain install` from a
port phase: poudriere fetches distfiles before the build, then blocks network
access during configure/build. Do not mix the FreeBSD-packaged Rust compiler
with upstream target components either; rustc rejects metadata from a different
compiler build even when the version number is the same.

The script downloads the official FreeBSD `BASIC-CLOUDINIT-zfs` image for the
selected architecture, creates a persistent qcow2 overlay with a relative
backing path, creates a NoCloud seed ISO, starts QEMU with host port forwarding,
syncs this ports tree into the VM with rsync, runs poudriere there, copies
`repo-output` back, and optionally uploads release assets with `gh`.

`PKG_REPO_SIGNING_KEY_B64` is required even when `PUBLISH=no`, because the flat
repository is signed before upload is considered. `gh` is only required when
publishing release assets from the builder host.

Use `scripts/local-qemu-build.sh reset` to stop the VM and remove generated
builder state for the selected architecture. The reset preserves downloaded
FreeBSD images but deletes the qcow2 overlay, cloud-init seed, SSH known-hosts
file, serial log, and UEFI variable store so the next run boots a fresh guest.

The release URL remains directly usable as a pkg repository URL:

```conf
foji: {
  url: "https://github.com/hazayan/foji-bsd/releases/download/repo-FreeBSD-15-aarch64",
  mirror_type: "none",
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/pkg/keys/foji.pub",
  enabled: yes
}
```
