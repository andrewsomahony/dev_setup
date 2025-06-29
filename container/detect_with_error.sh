#! /usr/bin/env bash

# We call our normal "detect" method, but we check the return value
# to see if we have a printed out container ID, and if so, we return 0.
# If we don't have a container ID, we return 1.
#
# This script is useful for methods that just care about the return code,
# like ones that just want to know if the current directory is bound to
# a container.

# We need the directory that our script is running in, to get our Dockerfile
# and our Flake
SCRIPT_DIRECTORY=$(dirname $(readlink -f $0))
# Use our detect_dir_container.sh script to find the running container
# in this directory

CONTAINER_ID=$($SCRIPT_DIRECTORY/detect.sh)

if [ -z $CONTAINER_ID ]; then
  exit 1
fi

