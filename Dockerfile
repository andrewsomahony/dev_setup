FROM nixos/nix

# Update our nixpkgs channel
RUN nix-channel --update

# We need to allow flakes and nix-command, so we do that with this command
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Copy over our flake.nix file, which we will use to create a devshell
COPY flake.nix /tmp/

# Set our working directory
WORKDIR /workspace

# Generate an SSH key pair (no passphrase, default location)
RUN ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# Run our Nix develop shell, which serves as the entrypoint
ENTRYPOINT [ "sleep", "infinity" ]
