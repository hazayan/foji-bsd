# foji-bsd Roadmap

## Shortcuts to revisit

- The GitHub Actions poudriere build uses `poudriere bulk -b latest` so dependencies are fetched from the upstream FreeBSD binary package repository when poudriere considers that acceptable. This keeps the first aarch64 milestone practical, but it means dependency provenance and option consistency are delegated to the upstream `latest` package set. Revisit with explicit fetch policy, blacklist/whitelist rules, or a fully controlled dependency rebuild strategy.
- The GitHub Actions build runs in an emulated aarch64 FreeBSD VM through `vmactions/freebsd-vm@v1` and creates the poudriere jail with `-X`, disabling native xtools. This avoids poudriere's amd64-to-aarch64 cross-toolchain path. Revisit if VM emulation is too slow or if dedicated arm64 runners become the better option.
- The workflow currently trusts the third-party `vmactions/freebsd-vm@v1` action for VM image acquisition. Revisit by pinning the action to a commit SHA and either verifying the VM image provenance/checksum path or taking direct control of the official FreeBSD image download.
- Poudriere state is cached with GitHub Actions cache under `.poudriere`, including jail, ports, package, distfile, and build cache state. This avoids repeatedly updating base and rebuilding heavy unchanged packages, but it makes GitHub cache state part of the build pipeline. Revisit with cache size controls, periodic clean rebuilds, and clearer cache invalidation.
- The workflow supports a manual `ports` input so CI can build a targeted subset during iteration instead of always including heavy ports such as `databases/manticore`. Revisit with automatic changed-port selection.
- The repository public key is distributed out of band by sysbsd, not from the GitHub release. Keep this trust flow explicit when adding node bootstrap automation.
