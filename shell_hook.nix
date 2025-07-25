# Returns a shell hook given the input variables, including the extra environment variables
# to be exported
{pkgs, custom_config, home_directory, extra_environment_variables, shell_code ? ''''}:
let
  environment_variable_exports = pkgs.lib.strings.concatLines (pkgs.lib.attrsets.mapAttrsToList (name: value: 
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

    # Print out our environment variable exports
    ${environment_variable_exports}
  '' + shell_code
