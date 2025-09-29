{ pkgs }:
pkgs.writeShellScriptBin "image-mounter" ''
    # Utility script to mount the main FS of the image so we don't have to constantly figure out
    # what offset we need to use and such
    
    usage() {
      echo "Usage: $0 <image_file> [partition_index]"
      echo ""
      echo "Examples:"
      echo "  $0 my-image.img        # Mount image as single partition"
      echo "  $0 disk.img 1          # Mount partition 1 from disk image"
      echo "  $0 disk.img 2          # Mount partition 2 from disk image"
      echo ""
      echo "This script will:"
      echo "- Create a loopback device for the image"
      echo "- Mount the filesystem to a temporary directory"
      echo "- Bind-mount /nix for binary access"
      echo "- Drop you into a chroot environment"
      echo "- Clean up automatically on exit"
      echo ""
      echo "Note: Requires root privileges"
    }
    
    MOUNT=${pkgs.util-linux}/bin/mount
    UMOUNT=${pkgs.util-linux}/bin/umount
    LOSETUP=${pkgs.util-linux}/bin/losetup
    FDISK=${pkgs.util-linux}/bin/fdisk

    cleanup() {
      if [ -n $MOUNT_POINT ]; then
        if mountpoint -q "$MOUNT_POINT/tools" ; then
          $UMOUNT "$MOUNT_POINT/tools"
          # Remove our tools directory
          rm -rf $MOUNT_POINT/tools
        fi
        if mountpoint -q "$MOUNT_POINT" ; then
          $UMOUNT $MOUNT_POINT
        fi
        # Remove our mount point
        rm -rf $MOUNT_POINT

        # Remove our chroot-tools temporary directory
        if mountpoint -q "/tmp/chroot-tools"; then
          $UMOUNT /tmp/chroot-tools
        fi
      fi
      $LOSETUP -D
    }
    trap cleanup ERR SIGINT EXIT
    
    set -e
    
    IMAGE_NAME=$1
    if [ -z $IMAGE_NAME ] || [ "$IMAGE_NAME" = "--help" ] || [ "$IMAGE_NAME" = "-h" ]; then
      usage
      exit 1
    fi
    
    PARTITION_INDEX=$2
    
    # If there is a partition index, then we figure out the offset of the partition
    # and create a loopback device that way
    if [ -n "$PARTITION_INDEX" ]; then
      SECTOR_SIZE=512
      # Get the offset of our sector
      SECTOR_OFFSET=$($FDISK -l $IMAGE_NAME | awk "match(\$0, /^[^ ]*$PARTITION_INDEX[ \t*]+([0-9]+)/, arr) { print arr[1]; exit }")
      RAW_OFFSET=$((SECTOR_OFFSET * SECTOR_SIZE))
      # Get a loopback device for us to use
      LOOPBACK_DEVICE=$($LOSETUP --find --show --offset $RAW_OFFSET $IMAGE_NAME)
    else
      # We don't have a partition index, so we assume the image is a partition itself
      # We just need to find a free loopback device
      LOOPBACK_DEVICE=$($LOSETUP --find --show $IMAGE_NAME)
    fi
    
    MOUNT_POINT=$(mktemp -d)

    # Mount our image
    $MOUNT $LOOPBACK_DEVICE $MOUNT_POINT

    mkdir -p /tmp/chroot-tools
    mount -t tmpfs -o size=64M tmpfs /tmp/chroot-tools

    BUILD_DIRECTORY=$(mktemp -d)

    nix build nixpkgs#pkgsStatic.busybox -o $BUILD_DIRECTORY/busybox-static
    install -D $BUILD_DIRECTORY/busybox-static/bin/busybox /tmp/chroot-tools/busybox
    ( cd /tmp/chroot-tools && ./busybox --install . )

    mkdir -p $MOUNT_POINT/tools
    mount --bind /tmp/chroot-tools "$MOUNT_POINT/tools"

    CHROOT_FULL_PATH=$(which chroot)

    PATH=/tools $CHROOT_FULL_PATH "$MOUNT_POINT" /tools/sh
  ''
