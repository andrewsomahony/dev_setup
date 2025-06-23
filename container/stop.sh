#! /usr/bin/env bash

# We need the directory that our script is running in, to get our Dockerfile
# and our Flake
SCRIPT_DIRECTORY=$(dirname $(readlink -f $0))
# Use our detect_dir_container.sh script to find the running container
# in this directory

CONTAINER_ID=$($SCRIPT_DIRECTORY/detect.sh)

if [ -n $CONTAINER_ID ]; then
  docker stop $CONTAINER_ID
  docker rm $CONTAINER_ID
else
  echo "No container found mounted to current directory."
fi
