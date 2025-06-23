#! /usr/bin/env bash

# !!! We need to find the dev container that is mounted in the current
# !!! directory and just stop and rm that one
#! /usr/bin/env bash

# This script attempts to detect the container that has the current working directory
# bound as a bind mount, as that's the one we are currently developing in.

# We do this using "jq" to parse the output of docker inspect, which lists all containers
# We want to parse out each array element returned by docker inspect, which we do with jq

CURRENT_DIRECTORY=$(pwd)

# Optional name filter
NAME_FILTER=$1

if [ -z $NAME_FILTER ]; then
  DOCKER_CONTAINER_ID_LIST=$(docker ps -q)
else
  DOCKER_CONTAINER_ID_LIST=$(docker ps -q -f "name=$NAME_FILTER")
fi

if [ -z "$DOCKER_CONTAINER_ID_LIST" ]; then
  exit 0
fi

# We now have our container objects, we need to get the mounts from the container objects

docker inspect $DOCKER_CONTAINER_ID_LIST | jq -c '.[]' | while read -r CONTAINER_OBJECT; do 
  CONTAINER_ID=$(jq -r '.Id' <<< $CONTAINER_OBJECT)

  # Loop through the container mounts and see if we have a bind mount with our
  # current directory.
  jq -r '.Mounts' <<< $CONTAINER_OBJECT | jq -c '.[]' | while read -r MOUNT_OBJECT; do
    DESTINATION_DIRECTORY=$(jq -r '.Source' <<< $MOUNT_OBJECT)
    # See if the destination directory is the same as our current working directory,
    # and if so, we have our container ID!
    if [ "$CURRENT_DIRECTORY" == "$DESTINATION_DIRECTORY" ]; then
      echo -n $CONTAINER_ID
      break
    fi
  done
done
