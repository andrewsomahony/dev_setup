#! /usr/bin/env bash

# Utility script to mount the main FS of the image so we don't have to constantly figure out
# what offset we need to use and such

cleanup() {
  if [ -n $MOUNT_POINT ]; then
    if mountpoint -q "$MOUNT_POINT/nix" ; then
      umount "$MOUNT_POINT/nix"
    fi
    if mountpoint -q "$MOUNT_POINT" ; then
      umount $MOUNT_POINT
    fi
    # Remove our mount point
    rm -rf $MOUNT_POINT
  fi
  losetup -D
}
trap cleanup ERR SIGINT EXIT

set -e

IMAGE_NAME=$1
if [ -z $IMAGE_NAME ]; then
  echo "Missing image name"
  exit 1
fi

PARTITION_INDEX=$2

# If there is a partition index, then we figure out the offset of the partition
# and create a loopback device that way
if [ -n "$PARTITION_INDEX" ]; then
  SECTOR_SIZE=512
  # Get the offset of our sector
  SECTOR_OFFSET=$(fdisk -l $IMAGE_NAME | awk "/^\/dev\/loop/ || /^[^ ]*$PARTITION_INDEX[ \t]/ { print \$2; exit }")
  RAW_OFFSET=$((SECTOR_OFFSET * SECTOR_SIZE))
  # Get a loopback device for us to use
  LOOPBACK_DEVICE=$(losetup --find --show --offset $RAW_OFFSET $IMAGE_NAME)
else
  # We don't have a partition index, so we assume the image is a partition itself
  # We just need to find a free loopback device
  LOOPBACK_DEVICE=$(losetup --find --show $IMAGE_NAME)
fi

MOUNT_POINT=$(mktemp -d)
mkdir -p $MOUNT_POINT

# Mount our image
mount $LOOPBACK_DEVICE $MOUNT_POINT

# Bind-Mount our Nix directory into the image, so we can access all
# the required binaries within the chroot
mkdir -p $MOUNT_POINT/nix
mount --bind /nix "$MOUNT_POINT/nix"

# Now we can chroot into our mount point and start BASH,
# and our root directory will effectively be in the image
chroot $MOUNT_POINT bash

