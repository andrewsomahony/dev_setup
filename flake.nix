{
  inputs.nixpkgs-unstable = {
    url = "github:NixOS/nixpkgs/nixos-unstable"; # Example branch for Linux
  };
  inputs.nixpkgs-stable = {
    url = "github:NixOS/nixpkgs/nixos-24.11"; # Example branch for macOS
  };
  inputs.nixpkgs = {
    url = "github:NixOS/nixpkgs";
  };
  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs-unstable, nixpkgs-stable, nixpkgs, utils }:
    let
      forAllSystems = utils.lib.eachDefaultSystem;
      # Get our homw directory as some of our files are there
      # !!! Why doesn't this work in the forAllSystems loop?
      home_directory = builtins.getEnv "HOME";

      nvim_config_rev = "8c0e55ca8db9f133133eb984617f2563096b74a8";
      fish_config_rev = "46586e3d30e708aa73123490fe3434972b5a85b5";
      stablePackagesRequired = false;
    in
      forAllSystems (system: 
        let 
          # Import our packages with the specific system
          unstablePackages = (import nixpkgs-unstable { inherit system; });
          stablePackages = (import nixpkgs-stable { inherit system; });

          # We use this one for claude-code
          mainPackages = (import nixpkgs { 
            inherit system; 
            config.allowUnfree = true;
            sandbox = false;
          });
          # We can't call isDarwin until we have an stdenv, which is when we are here,
          # so we set this boolean here
          pkgs = if stablePackagesRequired then stablePackages else unstablePackages;
          python = pkgs.python3;

          aom_fish = 
            pkgs.stdenv.mkDerivation {
              name = "aom_fish";
              src = import ./github.nix {
                owner = "andrewsomahony";
                repo = "fish_config";
                rev = fish_config_rev;
              };
              buildPhase = ''
              '';
              installPhase = ''
                cp -R . $out
              '';
            };
          aom_nvim = 
            pkgs.stdenv.mkDerivation {
              name = "aom_nvim";
              src = import ./github.nix {
                owner = "andrewsomahony";
                repo = "nvim_config";
                rev = nvim_config_rev;
              };
              postUnpack = ''
                # Dynamically generate our NVIM options for Nix
                
                # We aren't using Mason
                echo "return {has_mason = false}" > $sourceRoot/lua/dynamic_options/mason.lua
                # LSP's that we are adding to our navigator plugin
                echo 'return {"asm_lsp","nixd","bashls","fish_lsp"}' > $sourceRoot/lua/dynamic_options/lsp_servers.lua
              '';
              buildPhase = ''
              '';
              installPhase = ''
                cp -R . $out
              '';
            };
          # Make a derivation just to store our custom configuration, which
          # we will set our XDG_CONFIG_HOME environment variable to
          custom_config = 
            pkgs.stdenv.mkDerivation {
              name = "custom_config";
              # Skip the unpacking phase, meaning we don't need a "src" attribute
              dontUnpack = true;
              buildPhase = ''
              '';
              installPhase = ''
                mkdir -p $out/nvim
                mkdir -p $out/fish
                cp -R ${aom_nvim}/. $out/nvim
                cp -R ${aom_fish}/. $out/fish
              '';
            };

          # Packages that we override the system-wide versions.  We do this if there are issues
          # with the Nix version of a package, so the optionals allows us to skip installing it 
          # if needed.

          # Fish shell for interaction ONLY if we are on Linux for now
          # this is because on Darwin, due to another build error, we cannot use
          # nixos-unstable, so we need to use an older repo.  However, the version of Fish
          # in this repo isn't very good, so we just use our local OSX fish shell.
          override_system_packages = pkgs.lib.optionals (!stablePackagesRequired) ( with pkgs; [ fish neovim ]);

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
             # Rust package manager
             cargo
             # Next generation Rust unit tester
             cargo-nextest
             # Rust LSP
             rust-analyzer
             # Rust sources
             rustPlatform.rustcSrc
             rustPlatform.rustLibSrc
             # Docker LSP
             dockerfile-language-server-nodejs
             # Fish Shell LSP
             fish-lsp
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
             mainPackages.claude-code
          ] ++ linux_packages ++ override_system_packages);
        in
        {
          devShells.default = import ./new_shell.nix {
            inherit pkgs;
            shell_hook = import ./shell_hook.nix { 
              inherit pkgs custom_config home_directory;
              extra_environment_variables = {
                RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}";
              };
            };
            packages = standard_dev_packages;
          };
        }
      );
}
