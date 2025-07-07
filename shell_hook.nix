# Returns a shell hook given the input variables, including the extra environment variables
# to be exported
{lib, custom_config, home_directory, shell, extra_environment_variables}:
let
  environment_variable_exports = lib.strings.concatLines (lib.attrsets.mapAttrsToList (name: value: 
    "export ${name}=${value}"
  ) extra_environment_variables);
in 
  ''
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
    export DEV_SHELL=${shell}

    # Print out our environment variable exports
    ${environment_variable_exports}
  ''
