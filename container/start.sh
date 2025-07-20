#! /usr/bin/env bash


# We need the directory that our script is running in, to get our Dockerfile
# and our Flake
SCRIPT_DIRECTORY=$(dirname $(readlink -f $0))
WORKING_DIRECTORY=$(pwd)

IMAGE_TAG="aom_dev_container"
NIX_SHELL=/bin/sh
SHELL=${DEV_SHELL:-$NIX_SHELL}
FLAKE_DIRECTORY=/root/

# See if we have a container running in this directory already

EXISTING_CONTAINER_ID=$($SCRIPT_DIRECTORY/detect.sh)
if [ -n "$EXISTING_CONTAINER_ID" ]; then
  # We can just execute our shell on the existing container to get a new shell in the container
  docker exec -it $EXISTING_CONTAINER_ID $NIX_SHELL -c "nix develop --impure $FLAKE_DIRECTORY --command $SHELL"
  exit 0
fi

# Build our Docker image
cd $SCRIPT_DIRECTORY/..
docker build -t $IMAGE_TAG .
cd $WORKING_DIRECTORY

UNIQUE_ID=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 13; echo)
CONTAINER_NAME=${IMAGE_TAG}_${UNIQUE_ID}

# Create our Nix container
# We want to bind our ssh directory so we can re-use our key without making it every
# single time
# We also want to set our DEV_SHELL environment variable so our desired shell is executed
# when "nix develop" is finished.
docker run -d \
          --name $CONTAINER_NAME \
          --privileged \
          --network host \
          --mount type=bind,src=$HOME/.ssh_dev,dst=/root/.ssh \
          --mount type=bind,src=$WORKING_DIRECTORY,dst=/workspace \
          $IMAGE_TAG

# Execute our shell by executing it as the "nix develop" command
docker exec -it $CONTAINER_NAME $NIX_SHELL -c "nix develop --impure $FLAKE_DIRECTORY --override-input sourceTree /workspace --command $SHELL"
