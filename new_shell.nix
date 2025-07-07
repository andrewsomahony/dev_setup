{pkgs, packages, shell_hook}:
   pkgs.mkShell {
     shellHook = shell_hook;
     packages = packages;
   }

