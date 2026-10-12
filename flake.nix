{
  inputs.nixpkgs-unstable = {
    url = "github:NixOS/nixpkgs/nixos-unstable"; # Example branch for Linux
  };
  inputs.nixpkgs-neovim = {
    url = "github:NixOS/nixpkgs/nixos-26.05"; # Example branch for macOS
  };
  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs-unstable, nixpkgs-neovim, utils }:
    let
      forAllSystems = utils.lib.eachDefaultSystem;
      # Get our homw directory as some of our files are there
      # !!! Why doesn't this work in the forAllSystems loop?
      home_directory = builtins.getEnv "HOME";
    in
      forAllSystems (system: 
        let 
          # Import our packages with the specific system
          unstablePackages = (import nixpkgs-unstable { inherit system; config.allowUnfree = true; });
          # We want to bind our Neovim to a specific hash, so we keep consistent
	        neovimPackages = (import nixpkgs-neovim { inherit system; config.allowUnfree = true; });

          # We can't call isDarwin until we have an stdenv, which is when we are here,
          # so we set this boolean here
          pkgs = unstablePackages;
          python = pkgs.python3;

          # Linux-specific packages
          linux_packages = pkgs.lib.optionals pkgs.stdenv.isLinux [
            # This package only works on Linux as it is using Linux-specific commands
            # like mount and umount, that are found in the util-linux Nix package
            (import ./mount.nix { inherit pkgs; })
          ];

          copy_and_run = import ./copy_and_run.nix { inherit pkgs; };
          standard_dev_packages = ( with pkgs; [
             # So we can copy and run packages with one command
             copy_and_run.ncar
             # So we can copy and reload OS'es with one command
             copy_and_run.ncosar
             git
             # Useful for monitoring progress of operations like dd
             pv
             # Useful for searching for files
             tree
             # So I don't have to keep installing "mount" and "fdisk" and such
             # into my local profile :D
             util-linux
             # Ripgrep for Neovim searching
             ripgrep
             # Nodejs for various LSP needs
             nodejs
             # Python for Neovim and other execution
             python 
             # Lua LSP
             lua-language-server 
             # Nix LSP
             nixd 
             # Clangd LSP
             clang-tools 
             # Pyright LSP
             pyright 
             # Golang
             go
             # Go LSP
             gopls
             # Rust compiler
             rustc
             # Rust LSP
             rust-analyzer
             # Rust package manager
             cargo
             # Next generation Rust unit tester
             cargo-nextest
             # Rust sources
             rustPlatform.rustcSrc
             rustPlatform.rustLibSrc
             # Docker LSP
             dockerfile-language-server-nodejs
             # Fish Shell LSP
             fish-lsp
             tree-sitter
             typescript-language-server
             typescript_7
             # Bash LSP
             bash-language-server
             # Rust debugger extension
             vscode-extensions.vadimcn.vscode-lldb
             # ASM LSP
             asm-lsp
             # Clang for Treesitter compilation when installing
             llvmPackages_latest.clang
             # LLVM's libcxx
             llvmPackages_latest.libcxx
             # LLVM's linker
             llvmPackages_latest.lld
             # Nom for building, with a much nicer output
             nix-output-monitor
             claude-code
	           neovimPackages.neovim
          ] ++ linux_packages);
        in
        {
          devShells.default = import ./new_shell.nix {
            inherit pkgs;
            shell_hook = import ./shell_hook.nix { 
              inherit pkgs home_directory;
              extra_environment_variables = {
                RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}";
              };
            };
            packages = standard_dev_packages;
          };
        }
      );
}
