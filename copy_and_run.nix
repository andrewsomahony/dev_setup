# This derivation makes a script that just copies and runs the package
# on the command line on the specified machine.  It is more here to get
# the path of the script before the copy.

{ pkgs }:
{
  # Nix Copy and Run shell application
  # Builds the derivation, grabs its real path, and then
  # copies it to the specified system and runs it

  ncar = pkgs.writeShellApplication {
    name = "ncar";
    runtimeInputs = with pkgs; [ nix-output-monitor sshs ];
    text = ''
      if [ -z "$1" ]; then
        echo "Missing package path"
        exit 1
      fi
      PACKAGE_PATH="$1"
      if [ -z "$2" ]; then
        echo "Missing destination"
        exit 1
      fi
      DESTINATION="$2"

      # Cleanup function
      function cleanup() {
        rm -rf result
      }

      # Trap on an error or interrupt signal or exit
      trap SIGINT ERR EXIT
      set -e

      # tailscale status | grep -E "cr[0-9]+(-crystal)?.*(active|idle)"

      nom build "$PACKAGE_PATH"

      # Get our real path
      # nix path-info doesn't work!
      REAL_PATH=$(realpath result)

      # Copy our derivation over to the destination
      nix copy --to "ssh://$DESTINATION" "$REAL_PATH"
      echo "Copy complete"

      # Find the executable in our real path on the remote system
      EXECUTABLE_PATH=$(ssh "$DESTINATION" -- find "$REAL_PATH" -type f -executable | head -n 1)
      # Run the executable

      echo "Running executable $EXECUTABLE_PATH"
      ssh "$DESTINATION" -- "$EXECUTABLE_PATH"
    '';
  };

  # Nix Copy OS and Reload shell application
  # Builds the OS configuration, copies it to the destination
  # system, and then activates it, followed by rebooting the 
  # destination system

  ncosar = pkgs.writeShellApplication {
    name = "ncosar";
    runtimeInputs = with pkgs; [ nix-output-monitor sshs ];
    text = ''
      if [ -z "$1" ]; then
        echo "Missing nixOS Configuration path"
        exit 1
      fi
      CONFIGURATION_PATH="$1"
      if [ -z "$2" ]; then
        echo "Missing destination"
        exit 1
      fi
      DESTINATION="$2"
  
      # Cleanup function
      function cleanup() {
        rm -rf result
      }
  
      # Trap on an error or interrupt signal or exit
      trap SIGINT ERR EXIT
      set -e
  
      # !!! We should make sure the path points to a nixosConfiguration
      nom build "$CONFIGURATION_PATH"
  
      # Get our real path
      # nix path-info doesn't work!
      REAL_PATH=$(realpath result)
  
      # Copy our derivation over to the destination
      nix copy --to "ssh://$DESTINATION" "$REAL_PATH"
      echo "Copy complete"
  
      # Activating new NixOS and rebooting
  
      echo "Activating NixOS..."
      ssh "$DESTINATION" -- activate "$REAL_PATH" boot
  
      echo "Rebooting system..."
      ssh "$DESTINATION" -- sudo reboot
    '';
  };
}
