#!/bin/sh
set -eu

if [ "$(uname -s)" != FreeBSD ]; then
	echo "This bootstrap is for a FreeBSD builder host." >&2
	exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root, for example: sudo sh $0" >&2
	exit 2
fi

ASSUME_ALWAYS_YES=yes pkg bootstrap -f
pkg update -f
pkg install -y \
	bash \
	ca_root_nss \
	curl \
	git \
	hut \
	pkg \
	poudriere \
	qemu-user-static \
	rsync \
	sudo

echo "FreeBSD builder packages installed."
echo "Next: set POUDRIERE_BASE to the intended build dataset and run scripts/check-builder-host.sh with FOJI_BUILDER_MODE=native-freebsd."
