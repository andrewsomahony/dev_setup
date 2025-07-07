FROM nixos/nix

# Update our nixpkgs channel
RUN nix-channel --update

# We need to allow flakes and nix-command, so we do that with this command
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Copy over our flake.nix file, which we will use to create a devshell
COPY *.nix /root/

RUN git config --global user.name "Andrew O'Mahony"
RUN git config --global user.email "andrewsomahony@gmail.com"
RUN git config --global core.editor nvim

# Set our working directory
WORKDIR /workspace

# Run our Nix develop shell, which serves as the entrypoint
ENTRYPOINT [ "sleep", "infinity" ]
