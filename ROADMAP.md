# foji-bsd Roadmap

## Shortcuts to revisit

- The GitHub Actions poudriere build uses `poudriere bulk -b latest` so dependencies are fetched from the upstream FreeBSD binary package repository when poudriere considers that acceptable. This keeps the first aarch64 milestone practical, but it means dependency provenance and option consistency are delegated to the upstream `latest` package set. Revisit with explicit fetch policy, blacklist/whitelist rules, or a fully controlled dependency rebuild strategy.
- The GitHub Actions build runs in an emulated aarch64 FreeBSD VM through `vmactions/freebsd-vm@v1` and creates the poudriere jail with `-X`, disabling native xtools. This avoids poudriere's amd64-to-aarch64 cross-toolchain path. Revisit if VM emulation is too slow or if dedicated arm64 runners become the better option.
- The workflow currently trusts the third-party `vmactions/freebsd-vm@v1` action for VM image acquisition. Revisit by pinning the action to a commit SHA and either verifying the VM image provenance/checksum path or taking direct control of the official FreeBSD image download.
- The initial CI path performs a full custom-port build on each run and does not preserve poudriere state between runs. Revisit once the build and publishing flow is stable.
- The repository public key is distributed out of band by sysbsd, not from the GitHub release. Keep this trust flow explicit when adding node bootstrap automation.
