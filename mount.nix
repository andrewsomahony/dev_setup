{ pkgs }:
let
  shell_script = pkgs.writeShellScriptBin "image-mounter" ''
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
        if mountpoint -q "$MOUNT_POINT/nix" ; then
          $UMOUNT "$MOUNT_POINT/nix"
        fi
        if mountpoint -q "$MOUNT_POINT" ; then
          $UMOUNT $MOUNT_POINT
        fi
        # Remove our mount point
        rm -rf $MOUNT_POINT
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
      SECTOR_OFFSET=$($FDISK -l $IMAGE_NAME | awk "/^\/dev\/loop/ || /^[^ ]*$PARTITION_INDEX[ \t]/ { print \$2; exit }")
      RAW_OFFSET=$((SECTOR_OFFSET * SECTOR_SIZE))
      # Get a loopback device for us to use
      LOOPBACK_DEVICE=$($LOSETUP --find --show --offset $RAW_OFFSET $IMAGE_NAME)
    else
      # We don't have a partition index, so we assume the image is a partition itself
      # We just need to find a free loopback device
      LOOPBACK_DEVICE=$($LOSETUP --find --show $IMAGE_NAME)
    fi
    
    MOUNT_POINT=$(mktemp -d)
    mkdir -p $MOUNT_POINT
    
    # Mount our image
    $MOUNT $LOOPBACK_DEVICE $MOUNT_POINT
    
    # Bind-Mount our Nix directory into the image, so we can access all
    # the required binaries within the chroot
    mkdir -p $MOUNT_POINT/nix
    mount --bind /nix "$MOUNT_POINT/nix"
    
    # Now we can chroot into our mount point and start BASH,
    # and our root directory will effectively be in the image
    chroot $MOUNT_POINT bash
  '';
in
  # Make a derivation to symbolic link our shell script so we can access it easier
  pkgs.stdenv.mkDerivation {
    name = "image-mounter-symlink";
    
    buildCommand = ''
      mkdir -p $out
      ln -s ${shell_script}/bin/image-mounter $out/image-mounter
    '';
  }
