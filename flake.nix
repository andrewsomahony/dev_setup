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
  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";

  outputs = { self, nixpkgs-unstable, nixpkgs-stable, nixpkgs, utils, pyproject-nix }:
    let
      forAllSystems = utils.lib.eachDefaultSystem;
      # Get our Dev Shell
      # !!! Why doesn't this work in the forAllSystems loop?
      dev_shell = builtins.getEnv "DEV_SHELL";
      home_directory = builtins.getEnv "HOME";

      nvim_config_rev = "7b51d1e5a03693f4fc42d3fb5cb4ddc8d0d6818c";
      fish_config_rev = "080a307470a244733a28d5b5c26f548396841ba2";
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
          standard_dev_packages = ( with pkgs; [
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
             # Fish shell for interaction ONLY if we are on Linux for now
             # this is because on Darwin, due to another build error, we cannot use
             # nixos-unstable, so we need to use an older repo.  However, the version of Fish
             # in this repo isn't very good, so we just use our local OSX fish shell.
          ] ++ lib.optionals (!stablePackagesRequired) [ fish neovim ]);
        in
        {
          devShells.default = import ./new_shell.nix {
            pkgs = pkgs;
            shell_hook = import ./shell_hook.nix { 
              lib = pkgs.lib; 
              custom_config = custom_config; 
              home_directory = home_directory;
              shell = dev_shell;
              extra_environment_variables = {
                RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}";
              };
            };
            packages = standard_dev_packages;
          };

          # Our Python3 development shell
          # We need a special one here because we can use all our standard packages,
          # but we also need the Python project-specific packages, which we can parse
          # from the pyproject file (pyproject.toml/requirements.txt/etc) in the current
          # directory
          devShells.python =
            let
              # Parse our pyproject.toml file in our directory
              project = pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };
            in 
              import ./new_shell.nix {
                pkgs = pkgs;
                shell_hook = import ./shell_hook.nix { 
                  lib = pkgs.lib; 
                  custom_config = custom_config; 
                  home_directory = home_directory;
                  shell = dev_shell;
                  extra_environment_variables = {
                    RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}";
                  };
                };
                # Include our Python packages into our devshell
                packages = standard_dev_packages 
                              ++ (python.withPackages (project.renderers.withPackages { inherit python; }));
              };
        }
      );
}
