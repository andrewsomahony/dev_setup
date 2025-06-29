{
  inputs.nixpkgs-unstable = {
    url = "github:NixOS/nixpkgs/nixos-unstable"; # Example branch for Linux
  };
  inputs.nixpkgs-stable = {
    url = "github:NixOS/nixpkgs/nixos-24.11"; # Example branch for macOS
  };
  inputs.utils.url = "github:numtide/flake-utils";
  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";

  outputs = { self, nixpkgs-unstable, nixpkgs-stable, utils, pyproject-nix }:
    let
      forAllSystems = utils.lib.eachDefaultSystem;
      # Get our Dev Shell
      # !!! Why doesn't this work in the forAllSystems loop?
      dev_shell = builtins.getEnv "DEV_SHELL";
      home_directory = builtins.getEnv "HOME";
    in
      forAllSystems (system: 
        let 
          unstablePackages = (import nixpkgs-unstable { inherit system; });
          stablePackages = (import nixpkgs-stable { inherit system; });
          # We can't call isDarwin until we have an stdenv, which is when we are here,
          # so we set this boolean here
          stablePackagesRequired = false;
          pkgs = if stablePackagesRequired then stablePackages else unstablePackages;
          python = pkgs.python3;

          aom_fish = 
            pkgs.stdenv.mkDerivation {
              name = "aom_fish";
              src = pkgs.fetchFromGitHub {
                owner = "andrewsomahony";
                repo = "fish_config";
                rev = "b4c0c99ad0e42c5b8543b4bd0f370b6a3113ca04";
                hash = "sha256-5eWZpA3v/vUEdNfVqDNeEQ12UEZIRj9Fg7oTTgcMD3M=";
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
              src = pkgs.fetchFromGitHub {
                owner = "andrewsomahony";
                repo = "nvim_config";
                rev = "7b51d1e5a03693f4fc42d3fb5cb4ddc8d0d6818c";
                hash = "sha256-ADgJDliysG1qQwhLPo6viPeyHhCaYvM1K/u3ztIqqS0=";
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
                # Copy our source root directory, the one with our updates, into the $out directory
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
        in 
        with pkgs; 
        {
          devShells.default = mkShell {
            DEV_SHELL = dev_shell;
            shellHook = ''
              # Set our configuration home directory to our custom Nix directory 
              # We have to do this after we install Cachix, as Cachix has to write to its
              # config directory, so we put it in the Nix profile

              # The Fish shell doesn't check the XDG config dirs directory, so we need
              # to set the HOME directory so it uses our custom config
              export XDG_CONFIG_HOME="${custom_config}"

              # Nix will check this environment variable, so we need to set it.
              # As long as our XDG_CONFIG_HOME directory doesn't have a nix/nix.conf
              # within it, we are safe to use both variables.
              export XDG_CONFIG_DIRS="${custom_config}:${home_directory}/.config"

              # Export our dev shell
              export DEV_SHELL=$DEV_SHELL

              # We need to export our Rust src path manually, as when we install
              # the lib src, it isn't done for us for some reason
              export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}

              # Execute our dev shell
              exec $DEV_SHELL
            '';
            packages = [
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
                # Fish shell for interaction ONLY if we are on Linux for now
                # this is because on Darwin, due to another build error, we cannot use
                # nixos-unstable, so we need to use an older repo.  However, the version of Fish
                # in this repo isn't very good, so we just use our local OSX fish shell.
            ] ++ lib.optionals (!stablePackagesRequired) [ fish neovim ];

          };

          devShells.rust = mkShell {
            shellHook = "exec fish";
            packages = [
              # Rust compiler
              rustc
              # Rust package manager
              cargo
              # Rust LSP
              rust-analyzer
              # vscode-lldb for Neotest debugging of Rust
              vscode-extensions.vadimcn.vscode-lldb
            ];
          };

          # Our Go devshell
          devShells.go = mkShell {
            shellHook = "exec fish";
            packages = [
              go
              gopls
            ];
          };

          # Our Python3 development shell
          devShells.python =
            let
              # Parse our pyproject.toml file in our directory
              project = pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };
            in 
              mkShell {
                shellHook = "exec fish";
                packages = [
                 # Set our packages to what our project interprets from its parsed list of dependencies,
                 # which make them compatible with the standard Python packages
                 (python.withPackages (project.renderers.withPackages { inherit python; }))
                ];
              };
        }
      );
}
