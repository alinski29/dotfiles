# Shared environment for zsh and bash.
#
# Sourced from `programs.zsh.initContent` and `programs.bash.initExtra` in
# nix/home.nix. Both are interactive shells only, so nothing that must work in a
# non-interactive shell belongs here: `ssh host 'cmd'`, scripts and anything that
# execs a binary directly all bypass this file. home.sessionPath in nix/home.nix
# covers PATH entries needed everywhere.
#
# POSIX sh only: no arrays, no `[[ ]]`, no zsh-only syntax. Anything zsh-specific
# belongs in nix/home.nix's programs.zsh options, so this file stays sourceable by
# bash on a machine where zsh is not installed yet.

# `~/.dotfiles` is the stable link bootstrap.sh/rebuild-env.sh create and the one
# nix/home.nix resolves every path through, so a moved checkout needs no edit here.
# Overridable for a shell that starts before the link exists.
export DOTFILES_HOME="${DOTFILES_HOME:-$HOME/.dotfiles}"

# --- XDG base directories ---------------------------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_DIRS="/etc/xdg"

# --- Default programs -------------------------------------------------------
# TERMINAL and BROWSER are deliberately absent: a headless role has no terminal
# emulator and no browser. nix/modules/desktop.nix sets both.
export EDITOR="nvim"
export HOSTNAME=localhost

export CONDA_HOME="$XDG_DATA_HOME/miniconda3"
export JAVA_HOME="/usr/lib/jvm/default"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export KDEHOME="$XDG_CONFIG_HOME/kde"
export MOZILLA_HOME="$XDG_DATA_HOME/mozilla"
export ION_HOME="$XDG_DATA_HOME/ion/dist"
export DOCKER_VOLUMES_HOME="$XDG_DATA_HOME/docker/volumes"
export DOCKER_COMPOSE_HOME="$XDG_CONFIG_HOME/docker-compose"

# --- Third-party config locations ------------------------------------------
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"

# --- Java / Go module plumbing ---------------------------------------------
# Prefs live outside $HOME/.java, which some tools otherwise create.
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
export GOPATH="$XDG_DATA_HOME/gon"
export GOPRIVATE="github.com/zendataorg/*"
export GONOSUMDB="github.com/zendataorg/*"

# --- Project data -----------------------------------------------------------
export STONKS_DATA_PATH="$HOME/syncthing/stonks/data"
export STONKS_CONFIG_PATH="$HOME/syncthing/stonks/config.json"

# Required for herdr to detect sandboxes (works with nono)
export HERDR_PROCESS_DETECTION=child-groups

# --- Pi coding agent --------------------------------------------------------
export PI_AGENT_BROWSER_ALLOW_DIRECT_BASH=1
export PI_FFF_MODE=override
export PI_SUBAGENT_MAX_DEPTH=1

# --- Secrets sourcing
SECRETS_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.env"
if [ -f "$SECRETS_ENV" ]; then
  . "$SECRETS_ENV"
elif [ -L "$SECRETS_ENV" ]; then
  printf 'sh/env.sh: %s is a dangling symlink -> %s\n' \
    "$SECRETS_ENV" "$(readlink "$SECRETS_ENV")" >&2
  printf 'sh/env.sh: place this machine\''s secrets file at the link target\n' >&2
fi
unset SECRETS_ENV

# --- PATH -------------------------------------------------------------------
PATH="/usr/local/bin:\
$JAVA_HOME/bin:\
$GOPATH/bin:\
$CARGO_HOME/bin:\
$XDG_DATA_HOME/coursier/bin:\
$XDG_DATA_HOME/stonks/bin:\
$XDG_CACHE_HOME/.bun/bin:\
$PATH"
export PATH

# `pi` itself comes from home-manager (nix/modules/coding-agent.nix). This wrapper
# only moves the pin: bump the flake input, then a home-manager switch re-points it.
PI_UPDATE_SCRIPT="$DOTFILES_HOME/scripts/pi-update.sh"
pi-update() { bash "$PI_UPDATE_SCRIPT" "$@"; }

# Sandboxed-by-default `pi`.
if [ -r "$DOTFILES_HOME/sh/pi-sandbox.sh" ]; then
  . "$DOTFILES_HOME/sh/pi-sandbox.sh"
else
  pi() {
    printf 'pi: %s is missing, refusing to run unsandboxed\n' \
      "$DOTFILES_HOME/sh/pi-sandbox.sh" >&2
    printf 'pi: use `command pi ...` if that is really what you want\n' >&2
    return 127
  }
fi
