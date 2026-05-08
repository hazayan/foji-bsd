# Builder Machine

The dedicated foji-bsd builder target is a FreeBSD/amd64 host with roughly
24 GiB RAM and 1-1.5 TiB of mixed SATA/NVMe SSD storage. FreeBSD runs the
package builder directly. Linux is a guest on the same hardware for Linux-side
workflows and is not in the critical path for foji-bsd package production.

## Bootstrap

Install host packages:

```sh
sudo sh scripts/bootstrap-freebsd-builder.sh
```

Validate the host:

```sh
FOJI_BUILDER_MODE=native-freebsd FOJI_BUILDER_ARCH=amd64 scripts/check-builder-host.sh
```

Run the default amd64 build:

```sh
export PKG_REPO_SIGNING_KEY_B64="$(base64 < pkg.key | tr -d '\n')"
POUDRIERE_BASE=/usr/local/poudriere \
PUBLISH=yes \
scripts/native-freebsd-build.sh all
```

## Storage

Keep storage configurable through `POUDRIERE_BASE`; do not bake pool names into
the builder scripts. The final pool and dataset names belong in the machine IaC
once the disks are installed.

Recommended dataset split:

```text
<pool>/foji/poudriere
<pool>/foji/poudriere/distfiles
<pool>/foji/poudriere/packages
<pool>/foji/poudriere/work
```

The build work area benefits most from fast storage. If NVMe space is limited,
prioritize work directories there and keep packages and distfiles on the larger
SATA tier. Keep compression enabled unless a measured build shows it is hurting
more than it helps.

The current scripts use `NO_ZFS=yes` in poudriere and point poudriere at
`POUDRIERE_BASE`. That keeps the first dedicated builder milestone simple: ZFS
provides host-level datasets, snapshots, and cleanup boundaries while poudriere
continues to use plain directories internally. Revisit poudriere-native ZFS
only after the machine is stable.

## Signing

Repository signing stays mandatory for local smoke builds and publication.
`PKG_REPO_SIGNING_KEY_B64` must be present because the flat repository is
signed before any upload step is considered.

This intentionally keeps test and production repository metadata on the same
trust path. If unsigned repositories are ever needed for a narrow debugging
case, add an explicit noisy opt-in such as `ALLOW_UNSIGNED_REPO=yes`; do not
make unsigned output the default.

## Ports Ref Refresh

The builder uses pinned `PORTS_REF` values to keep poudriere aligned with the
binary package branch and avoid surprise rebuilds of large dependencies.
Refresh those pins deliberately:

1. Resolve the current quarterly branch head.
2. Run a targeted build with `PORTS_REF` set to that candidate.
3. Confirm large dependencies are fetched as packages instead of rebuilt.
4. Update the script defaults and commit the pin bump with the build result.

Use the dry-run helper:

```sh
scripts/refresh-ports-ref.sh all
```

The helper does not edit files. It prints the current pin, candidate branch
head, and validation commands to run before changing defaults.

## Open Decisions

- Final ZFS pool and dataset names.
- Whether `POUDRIERE_BASE` should live entirely on one pool or split work,
  packages, and distfiles across tiers with symlinks or mountpoints.
- Whether poudriere-native ZFS is worth enabling after the first stable native
  builder is proven.
