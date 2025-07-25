# This derivation makes a script that just copies and runs the package
# on the command line on the specified machine.  It is more here to get
# the path of the script before the copy.

{ pkgs }:
  pkgs.writeShellScriptBin "ncar" ''
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

    REAL_PATH=$(nix path-info $PACKAGE_PATH)
    nix copy --to ssh://$DESTINATION $PACKAGE_PATH

    ssh $DESTINATION -- $PACKAGE_PATH
  ''
