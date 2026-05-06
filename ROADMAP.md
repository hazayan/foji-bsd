# foji-bsd Roadmap

## Shortcuts to revisit

- Local QEMU builds use official FreeBSD `BASIC-CLOUDINIT-zfs` images and persistent qcow2 overlays under `FOJI_FORGE_DIR`. This removes GitHub runner/cache coupling, but the dedicated build machine should eventually pin image checksums and document the refresh process.
- The local builder host currently depends on distro package names such as `qemu-full`, `edk2-ovmf`, `edk2-aarch64`, `cdrtools`, `rsync`, `openssh`, `github-cli`, `curl`, and `xz`. Convert these observed package requirements into IaC once the dedicated build machine target distribution is fixed.
- The local poudriere build fetches dependencies from the upstream FreeBSD binary package repository when poudriere considers that acceptable. Both local builder architectures currently use `quarterly` plus temporary 2026Q2 `PORTS_REF` pins so `lang/rust` and its dependency closure are fetched instead of built. Revisit these pins as the upstream package sets move.
- Poudriere still rebuilds `ports-mgmt/pkg` because package fetch marks it as blacklisted. This is acceptable for the first aarch64 milestone but should be revisited if build time becomes sensitive.
- GitHub release assets normalize comma-containing filenames, which breaks FreeBSD package filenames that use epochs such as `brotli-1.2.0,1.pkg`. Publish filtered custom runtime packages to GitHub releases unless a different repository host is chosen.
- Rust-based `amd64` ports now use a rustup-managed build toolchain instead of depending directly on `lang/rust`; `aarch64` cannot use FreeBSD `devel/rustup-init` today because that port is `amd64`-only. Revisit aarch64 Rust build strategy if upstream rustup host support changes.
- `databases/manticore` is intentionally `amd64`-only for now because it is intended for server nodes and made the first aarch64 builder run impractically long. Revisit if an aarch64 consumer appears.
- The local builder supports targeted port input through `REQUESTED_PORTS`, and `FOJI_BUILD_PROFILE=kunci` sets the known-safe lightweight publication path. Revisit with automatic changed-port selection.
- GitHub Actions no longer performs FreeBSD package builds. Keep GitHub as source control and release hosting only unless a future runner path becomes substantially simpler and cheaper than the dedicated builder machine.
- The repository public key is distributed out of band by sysbsd, not from the GitHub release. Keep this trust flow explicit when adding node bootstrap automation.
