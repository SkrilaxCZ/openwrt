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

# If on desktop, 12 processes (VM with 32 GB RAM)
# On ARM SBC, 4 processes (Jetson Xavier NX with 8 GB RAM)
# Getting OOM errors when trying to use $(n_proc) with < 16 GB RAM
if [ "$MY_ARCH" == "x86_64" ]; then
	N_PROC=12
else
	N_PROC=4
fi

echo "Building OpenWRT ..."
echo "Host ARCH: $MY_ARCH"
echo "Num processes: $N_PROC"

# Cleanup fully
make distclean

# Update feeds
./scripts/feeds update -a

# Patch feeds
(cd feeds/luci && patch -p1 < "$SCRIPT_DIR/luci.patch")
(cd feeds/packages && patch -p1 < "$SCRIPT_DIR/packages.patch")

# Install feeds
./scripts/feeds update -i
./scripts/feeds install -a

# Put patches in feeds under version control
(cd feeds/luci && git add -A)
(cd feeds/packages && git add -A)

# Initialize config
cp "$SCRIPT_DIR/XR500_config" .config

# Make defconfig
make defconfig

# Make download
make download

# Kernel
make target/linux/clean
make -j $N_PROC V=s target/linux/compile

# Image
make -j $N_PROC V=s world

