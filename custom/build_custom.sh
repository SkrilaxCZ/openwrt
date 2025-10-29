#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )
CWD="$PWD"

function finish {
	cd "$CWD"
}

trap finish EXIT

cd "$ROOT_DIR"

MY_ARCH=$(arch)
N_PROC=6

echo "Building OpenWRT ..."
echo "Host ARCH: $MY_ARCH"
echo "Num processes: $N_PROC"

# Cleanup fully
make distclean

# Update feeds
./scripts/feeds update -a

# Patch feeds
(cd feeds/luci && patch --no-backup-if-mismatch -p1 < "$SCRIPT_DIR/luci.patch")
if [ $? -ne 0 ]; then
	echo "Patching luci failed!"
	exit 1
fi

(cd feeds/packages && patch --no-backup-if-mismatch -p1 < "$SCRIPT_DIR/packages.patch")
if [ $? -ne 0 ]; then
	echo "Patching packages failed!"
	exit 1
fi

# Install feeds
./scripts/feeds update -i
./scripts/feeds install -a

# Put patches in feeds under version control
(cd feeds/luci && git add -A)
(cd feeds/packages && git add -A)

# Specific patches to put
cp "$SCRIPT_DIR/patches/dahdi-linux/"* feeds/telephony/libs/dahdi-linux/patches
(cd feeds/telephony && git add -A)

# Initialize config
cp "$SCRIPT_DIR/nanopi_r6s.config" .config

# Make defconfig
make defconfig

# Make download
make download

# Clean
make clean

# Image
make -j $N_PROC V=s world

