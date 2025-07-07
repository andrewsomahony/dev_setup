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
    in
      forAllSystems (system: 
        let 
          unstablePackages = (import nixpkgs-unstable { inherit system; });
          stablePackages = (import nixpkgs-stable { inherit system; });
          mainPackages = (import nixpkgs { 
            inherit system; 
            config.allowUnfree = true;
            sandbox = false;
          });
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
                rev = "0a02b8268f01d6b286b647279455dc63f217a0d2";
                hash = "sha256-UcBE0YxQgMLnvqbzQ/EthtictmF2TpTOJwIXzUleBaw=";
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
        with pkgs;
        {
          devShells.default = import ./new_shell.nix {
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
          # devShells.default = mkShell {
          #   shellHook = import ./shell_hook.nix { 
          #     lib = pkgs.lib; 
          #     custom_config = custom_config; 
          #     home_directory = home_directory;
          #     shell = dev_shell;
          #     extra_environment_variables = {
          #       RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}";
          #     };
          #   };
          #   packages = standard_dev_packages;
      #             packages = [
      #                 # Ripgrep for Neovim searching
      #                 ripgrep
      #                 # Nodejs for various LSP needs
      #                 nodejs
      #                 # Python for Neovim and other execution
      #                 python 
      #                 # Lua LSP
      #                 lua-language-server 
      #                 # Nix LSP
      #                 nixd 
      #                 # Clangd LSP
      #                 clang-tools 
      #                 # Pyright LSP
      #                 pyright 
      #                 # Golang
      #                 go
      #                 # Go LSP
      #                 gopls
      #                 # Rust compiler
      #                 rustc
      #                 # Rust package manager
      #                 cargo
      #                 # Next generation Rust unit tester
      #                 cargo-nextest
      #                 # Rust LSP
      #                 rust-analyzer
      #                 # Rust sources
      #                 rustPlatform.rustcSrc
      #                 rustPlatform.rustLibSrc
      #                 # Docker LSP
      #                 dockerfile-language-server-nodejs
      #                 # Fish Shell LSP
      #                 fish-lsp
      #                 # Bash LSP
      #                 bash-language-server
      #                 # Rust debugger extension
      #                 vscode-extensions.vadimcn.vscode-lldb
      #                 # ASM LSP
      #                 asm-lsp
      #                 # Clang for Treesitter compilation when installing
      #                 llvmPackages_latest.clang
      #                 # LLVM's libcxx
      #                 llvmPackages_latest.libcxx
      #                 # LLVM's linker
      #                 llvmPackages_latest.lld
      #                 # Nom for building, with a much nicer output
      #                 nix-output-monitor
      #                 mainPackages.claude-code
      #                 # Fish shell for interaction ONLY if we are on Linux for now
      #                 # this is because on Darwin, due to another build error, we cannot use
      #                 # nixos-unstable, so we need to use an older repo.  However, the version of Fish
      #                 # in this repo isn't very good, so we just use our local OSX fish shell.
      #             ] ++ lib.optionals (!stablePackagesRequired) [ fish neovim ];
          # };

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
