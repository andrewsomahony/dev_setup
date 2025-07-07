# Utility method to fetch from github, getting the correct hash first to avoid having to run
# nix build and copy-paste all the time
{owner, repo, rev}:
    # We don't want to be bothering with our hashes all the time, so we just use
    # fetchGit to prevent us from having to get the hash every time we change the rev
    builtins.fetchGit {
      url = "https://github.com/${owner}/${repo}.git";
      rev = "${rev}";
    }
