# foji-bsd Roadmap

## Shortcuts to revisit

- The GitHub Actions poudriere build uses `poudriere bulk -b latest` so dependencies are fetched from the upstream FreeBSD binary package repository when poudriere considers that acceptable. This keeps the first aarch64 milestone practical, but it means dependency provenance and option consistency are delegated to the upstream `latest` package set. Revisit with explicit fetch policy, blacklist/whitelist rules, or a fully controlled dependency rebuild strategy.
- The initial CI path performs a full custom-port build on each run and does not preserve poudriere state between runs. Revisit once the build and publishing flow is stable.
- The repository public key is distributed out of band by sysbsd, not from the GitHub release. Keep this trust flow explicit when adding node bootstrap automation.
