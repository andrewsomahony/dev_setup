#! /usr/bin/env bash

# This script attempts to detect the container that has the current working directory
# bound as a bind mount, as that's the one we are currently developing in.

# We do this using "jq" to parse the output of docker inspect, which lists all containers
# We want to parse out each array element returned by docker inspect, which we do with jq

CURRENT_DIRECTORY=$(pwd)

# Optional name filter
NAME_FILTER=$1

# !!! We need to check if Docker is even running, and if not, just quit silently

if [ -z $NAME_FILTER ]; then
  DOCKER_CONTAINER_ID_LIST=$(docker ps -q)
else
  DOCKER_CONTAINER_ID_LIST=$(docker ps -q -f "name=$NAME_FILTER")
fi

# Check if we have any containers at all, and if not, exit
# !!! This check feels so flimsy, as docker ps will always print something even if there
# !!! are no containers!
if [[ -z "$DOCKER_CONTAINER_ID_LIST" || "$DOCKER_CONTAINER_ID_LIST" == "" ]]; then
  exit 0
fi

# We now have our container objects, we need to get the mounts from the container objects

docker inspect $DOCKER_CONTAINER_ID_LIST | jq -c '.[]' | while read -r CONTAINER_OBJECT; do 
  CONTAINER_ID=$(jq -r '.Id' <<< $CONTAINER_OBJECT)

  # Loop through the container mounts and see if we have a bind mount with our
  # current directory.
  jq -r '.Mounts' <<< $CONTAINER_OBJECT | jq -c '.[]' | while read -r MOUNT_OBJECT; do
    SOURCE_DIRECTORY=$(jq -r '.Source' <<< $MOUNT_OBJECT)
    # See if the destination directory is the same as our current working directory,
    # and if so, we have our container ID!
    if [ "$CURRENT_DIRECTORY" == "$SOURCE_DIRECTORY" ]; then
      echo -n $CONTAINER_ID
      break
    fi
  done
done
