# foji-bsd

Custom FreeBSD ports tree and local package repository builder.

Porting conventions for custom ports live in [PORTING.md](PORTING.md).

## Encrypted Beads Export

The Beads working export stays plaintext at `.beads/issues.jsonl` so `bd` can
read and update it normally. Git stores that file through `git-crypt`, so the
blob published to SourceHut is encrypted while the local checkout remains usable
after `git-crypt unlock`.

This repository grants unlock access to GPG key `83D121B5F6A8A730`.

Fresh clones need:

```sh
git-crypt unlock
bd bootstrap
```

The Beads-managed pre-commit hook exports current issue state before each
commit. The local hook should then run:

```sh
scripts/check-beads-git-crypt.sh
```

That check verifies `.beads/issues.jsonl` is plaintext in the working tree,
has no unstaged post-export drift, is covered by the `git-crypt` filter, and is
staged as an encrypted `GITCRYPT` blob. If the file was already tracked before
the encryption attribute was added, refresh the index once with:

```sh
git-crypt status -f
```

## Local QEMU builder

The repository currently supports two builder paths:

- Native FreeBSD host: the preferred path for the dedicated builder machine.
- Local QEMU FreeBSD guest: the workstation fallback used during bring-up.

The finished flat pkg repository can be uploaded to SourceHut Pages. SourceHut
is the primary source control and package repository hosting target; GitHub is
only a read-only mirror synced explicitly after the daily cutoff.

## Native FreeBSD Builder

The dedicated builder target is a FreeBSD/amd64 host with roughly 24 GiB RAM
and 1-1.5 TiB mixed SATA/NVMe SSD storage. FreeBSD should host poudriere
directly. Linux becomes a guest on that machine for Linux-centric work; it is
not in the critical path for foji-bsd package builds.

Bootstrap host packages:

```sh
sudo sh scripts/bootstrap-freebsd-builder.sh
```

Validate host readiness:

```sh
FOJI_BUILDER_MODE=native-freebsd FOJI_BUILDER_ARCH=amd64 scripts/check-builder-host.sh
```

Run the default full amd64 profile directly on the FreeBSD host:

```sh
export PKG_REPO_SIGNING_KEY_B64="$(base64 < pkg.key | tr -d '\n')"
POUDRIERE_BASE=/usr/local/poudriere \
PUBLISH=yes \
scripts/native-freebsd-build.sh all
```

Storage layout is intentionally not hardcoded yet. Put `POUDRIERE_BASE` on the
largest reliable build dataset, preferably on the faster SSD tier if there is
room for poudriere jails, packages, distfiles, and work directories. Keep the
exact ZFS pool/dataset names as builder-machine IaC once the final disks are
known.

## Local QEMU Builder

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
FREEBSD_IMAGE_SHA512=<expected image checksum>
REQUESTED_PORTS=auto
RELEASE_TARGET=sourcehut-pages
SOURCEHUT_PAGES_DOMAIN=ylabidi.srht.site
PUBLISH=no
```

Host packages observed on the current Artix/CachyOS-style builder:

```sh
pacman -S qemu-full edk2-ovmf edk2-aarch64 cdrtools openssh openbsd-netcat rsync hut curl xz
```

Validate a candidate builder host without installing anything:

```sh
FOJI_BUILDER_ARCH=amd64 scripts/check-builder-host.sh
FOJI_BUILDER_ARCH=aarch64 scripts/check-builder-host.sh
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

The default FreeBSD 15.0 amd64 and aarch64 `BASIC-CLOUDINIT-zfs.raw.xz` images
are pinned by SHA512 before they are decompressed or used as qcow2 backing
images. When overriding `FREEBSD_IMAGE_URL`, also set `FREEBSD_IMAGE_SHA512` to
the expected digest. Use `FREEBSD_IMAGE_SHA512=skip` only for an explicitly
trusted local test image.

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

Poudriere may still build `ports-mgmt/pkg` even when `-b quarterly` is active.
That is expected when the binary package cannot be accepted under poudriere's
package-fetch rules. It only uses fetched packages that match the local
version, ABI, runtime and library dependencies, options, and blacklist policy.
Use `POUDRIERE_BULK_FLAGS="-vv"` when diagnosing fetch decisions; avoid
overriding this unless `pkg` build time becomes material.

Check how far the temporary 2026Q2 `PORTS_REF` pins are from the live branch:

```sh
scripts/show-ports-ref-pins.sh
```

Refreshing those pins should be paired with a targeted build that proves large
binary dependencies are still fetched rather than rebuilt.

An amd64 relocation smoke run on `altair` with `FOJI_FORGE_DIR=/data/workspace/forge`,
`FOJI_BUILD_PROFILE=kunci`, and `PUBLISH=no` completed the full local cycle:
KVM boot, rsync into the guest, poudriere build, signed flat repository
creation, and fetch back to the host. That first-run path created the poudriere
jail from binary release sets and applied `freebsd-update`; it did not compile
FreeBSD base.

SourceHut Pages can publish the flat repository as-is because it preserves a
normal directory layout and filenames. The default publication target is:

```sh
RELEASE_TARGET=sourcehut-pages
SOURCEHUT_PAGES_DOMAIN=ylabidi.srht.site
SOURCEHUT_PAGES_SUBDIR=/foji-bsd/repo-FreeBSD-15-aarch64
```

GitHub release publication remains available as an explicit compatibility path:

```sh
RELEASE_TARGET=github
```

For GitHub release publication, prefer filtering the exported repository to
custom runtime packages, for example `FOJI_BUILD_PROFILE=kunci`. The complete
poudriere output is useful for diagnostics, but upstream package filenames may
contain commas for epochs. GitHub release assets normalize those commas, which
breaks pkg repository metadata for those upstream packages.

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

For local iteration on ports changed since the primary SourceHut branch, use:

```sh
FOJI_BUILD_PROFILE=changed
```

That profile uses `scripts/list-changed-ports.sh` to inspect changes since
`CHANGED_SINCE`, defaulting to `zung/main`, plus staged and unstaged working
tree changes. It sets both `REQUESTED_PORTS` and `REPO_PACKAGE_ORIGINS` to the
detected custom port origins. Use explicit profiles such as `foji-amd64` for
final publication when the release must preserve the full package set.

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

For aarch64 Rust ports, keep using the normal FreeBSD `lang/rust` package path
for now. As of the FreeBSD `2026Q2` ports branch, `devel/rustup-init` is still
`ONLY_FOR_ARCHS=amd64`, so the amd64 rustup-managed pattern is not portable to
the aarch64 builder yet.

The script downloads the official FreeBSD `BASIC-CLOUDINIT-zfs` image for the
selected architecture, creates a persistent qcow2 overlay with a relative
backing path, creates a NoCloud seed ISO, starts QEMU with host port forwarding,
syncs this ports tree into the VM with rsync, runs poudriere there, copies
`repo-output` back, and optionally publishes the repository with `hut`.

`PKG_REPO_SIGNING_KEY_B64` is required even when `PUBLISH=no`, because the flat
repository is signed before upload is considered. `hut` is required when
publishing to SourceHut Pages. `gh` is only required when explicitly publishing
to GitHub releases with `RELEASE_TARGET=github`.

Use `scripts/local-qemu-build.sh reset` to stop the VM and remove generated
builder state for the selected architecture. The reset preserves downloaded
FreeBSD images but deletes the qcow2 overlay, cloud-init seed, SSH known-hosts
file, serial log, and UEFI variable store so the next run boots a fresh guest.

The SourceHut Pages URL remains directly usable as a pkg repository URL:

```conf
foji: {
  url: "https://ylabidi.srht.site/foji-bsd/repo-FreeBSD-15-aarch64",
  mirror_type: "none",
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/pkg/keys/foji.pub",
  enabled: yes
}
```

The repository public key is intentionally not sourced from the package
repository itself. Distribute `foji.pub` through sysbsd or another trusted node
bootstrap path before enabling the repository. The package repository URL is a
distribution endpoint, not the root of trust.

## Source Control

The primary remote is SourceHut:

```sh
git remote set-url zung git@git.sr.ht:~ylabidi/foji-bsd
git config remote.pushDefault zung
git config branch.main.remote zung
git config branch.main.merge refs/heads/main
```

The local `origin` push URL should remain blocked to prevent accidental GitHub
pushes:

```sh
git config remote.origin.pushurl DISABLED-GITHUB-MIRROR-USE-SCRIPT
```

GitHub mirror sync is explicit and time-gated:

```sh
scripts/mirror-github.sh
```

The mirror script refuses to run before 19:00 local time unless
`GITHUB_MIRROR_FORCE_TIME=yes` is set. It keeps GitHub an exact mirror of
SourceHut history. It does not rewrite commit timestamps because that would
create different object IDs and make the mirror diverge from the primary
repository.
