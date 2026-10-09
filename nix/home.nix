# Shared home-manager configuration: what every role gets, whatever else it imports.
#
# Three layers, deliberately kept separate:
#   1. this file       - packages, shell, prompt, symlinks common to all roles;
#   2. nix/modules/    - one capability per file, listed per role in roles.nix;
#   3. nix/flake.nix   - the flake inputs. `pi` is declared there and installed by modules/coding-agent.nix,
#                        which also owns its coding tools (go, gopls, uv, bun, codegraph, ...).
{
  config,
  lib,
  pkgs,
  role,
  user,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  dotfiles = "${homeDir}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  # The value comes from nix/roles.nix via extraSpecialArgs.
  home.username = user;
  home.homeDirectory = "/home/${user}";
  # 26.05 is what makes programs.zsh.dotDir default to ~/.config/zsh rather
  # than $HOME. It is a compatibility switch: do not bump it casually.
  home.stateVersion = "26.05";
  home.sessionPath = [
    "${homeDir}/.local/bin"
  ];

  xdg.enable = true;
  targets.genericLinux.enable = true;
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
      # Shell and prompt (starship itself is added by its module below)
      bash
      zsh
      fzf
      git
      ripgrep
      ast-grep
      fd
      gh
      jq
      eza
      curl
      neovim
      herdr
      nerd-fonts.hack
      nerd-fonts.commit-mono
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      gnumake
      stdenv.cc
    ];

  home.file = {
    ".config/nvim".source = link "neovim";
    ".config/herdr/config.toml".source = link "herdr/config.toml";
    # The global skill manifest.
    ".agents/skills.txt".source = link ".agents/global-skills.txt";
    ".local/bin/rebuild-env".source = link "scripts/rebuild-env.sh";
    # Per-role secrets file, chosen at build time from the role in nix/roles.nix.
    # Hand-placed at an absolute path in $HOME, deliberately *outside* the repo".
    ".config/zsh/secrets.env".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.xdg.configHome}/zsh-secrets/secrets.${role}.env";
  };

  programs.zsh = {
    enable = true;
    # Owns ~/.zshenv, ~/.config/zsh/.zshenv and ~/.config/zsh/.zshrc.
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # zsh links `main` to viins when $VISUAL or $EDITOR *contains* the substring
    # "vi" at startup, which sh/env.sh's EDITOR=nvim does, so without this the
    # shell silently comes up in vi mode and ^A/^E/^C self-insert instead of
    # doing beginning-of-line/end-of-line/abort-line.
    defaultKeymap = "emacs";

    # compinit writes a ~50KB dump next to the rc file by default, which is
    # exactly why ~/.config/zsh had accumulated .zcompdump* files. Send it to the
    # cache directory, keyed by zsh version, so $ZDOTDIR only ever holds rc files.
    completionInit = ''
      mkdir -p "${config.xdg.cacheHome}/zsh"
      autoload -U compinit && compinit -d "${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION"
    '';

    history = {
      path = "${config.xdg.dataHome}/zsh/history";
      size = 2000;
      save = 2000;
    };

    shellAliases = {
      vim = "nvim";
      vi = "nvim";
      ls = "eza";
      sg = "ast-grep";
      wrangler = "bunx wrangler";
    };

    # mkOrder 950 places it after the history block (910) and before starship
    # (default 1000), so the prompt sees the final PATH.
    initContent = lib.mkOrder 950 ''
      . "${dotfiles}/sh/env.sh"
    '';
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      . "${dotfiles}/sh/env.sh"

      # Hand interactive bash sessions over to zsh. home-manager cannot change
      # the login shell - it lives in /etc/passwd and only NixOS's
      # users.users.<name>.shell reaches it - so this is what actually gets you
      # into zsh on a standalone Nix host. Three guards, all load-bearing:
      #   *i*             leaves `ssh host 'cmd'`, scp and rsync on plain bash
      #   command -v zsh  stops a shell that would exec into nothing and die
      #   DOTFILES_NO_ZSH stops recursion and is the escape hatch:
      #                     DOTFILES_NO_ZSH=1 bash
      if [[ $- == *i* && -z $ZSH_VERSION && -z $DOTFILES_NO_ZSH ]]; then
        # Prefer the distro shell over the Nix one for the same reason the
        # login shell is a distro package: it exists even when the Nix profile
        # is broken. Fall back to whatever `zsh` is on PATH.
        zsh_bin=/usr/bin/zsh
        [ -x "$zsh_bin" ] || zsh_bin="$(command -v zsh || true)"
        if [ -n "$zsh_bin" ]; then
          export DOTFILES_NO_ZSH=1
          exec "$zsh_bin" -l
        fi
      fi
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };
}
