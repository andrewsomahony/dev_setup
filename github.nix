# Utility method to fetch from github, getting the correct hash first to avoid having to run
# nix build and copy-paste all the time
{pkgs, owner, repo, rev}:
  let
    repo_information = pkgs.runCommand "repo-information" {
      buildInputs = [
        pkgs.jq
      ];
    } ''
      nix-prefetch-github ${owner} ${repo} --rev ${rev} | jq -r ".hash" > $out
    '';
    repo_hash = builtins.readFile "${repo_information}";
  in
    pkgs.fetchFromGitHub {
      owner = owner;
      repo = repo;
      rev = rev;
      hash = repo_hash;
    }
