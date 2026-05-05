# foji-bsd Roadmap

## Shortcuts to revisit

- Local QEMU builds use official FreeBSD `BASIC-CLOUDINIT-zfs` images and persistent qcow2 overlays under `FOJI_FORGE_DIR`. This removes GitHub runner/cache coupling, but the dedicated build machine should eventually pin image checksums and document the refresh process.
- The local builder host currently depends on distro package names such as `qemu-full`, `edk2-ovmf`, `edk2-aarch64`, `cdrtools`, `rsync`, `openssh`, `github-cli`, `curl`, and `xz`. Convert these observed package requirements into IaC once the dedicated build machine target distribution is fixed.
- The local poudriere build uses `poudriere bulk -b latest` so dependencies are fetched from the upstream FreeBSD binary package repository when poudriere considers that acceptable. This keeps the first aarch64 milestone practical, but it means dependency provenance and option consistency are delegated to the upstream `latest` package set. Revisit with explicit fetch policy, blacklist/whitelist rules, or a fully controlled dependency rebuild strategy.
- In the first local aarch64 run, `poudriere bulk -b latest` fetched some binary packages but discarded them when their dependency closure was incomplete in the local repo cache, then built 47 packages from source, including `pkg`, `gettext-runtime`, `gettext-tools`, and `python311`. Revisit the binary dependency policy before treating the local builder as operationally efficient.
- The local builder supports targeted port input through `REQUESTED_PORTS`, so iteration can avoid always including heavy ports such as `databases/manticore`. Revisit with automatic changed-port selection.
- GitHub Actions no longer performs FreeBSD package builds. Keep GitHub as source control and release hosting only unless a future runner path becomes substantially simpler and cheaper than the dedicated builder machine.
- The repository public key is distributed out of band by sysbsd, not from the GitHub release. Keep this trust flow explicit when adding node bootstrap automation.
