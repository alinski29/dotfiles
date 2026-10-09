#!/usr/bin/env bash
# pi-update - move this flake's `pi` and `nixpkgs` inputs, then apply the
# home-manager switch.
#
#   pi-update                    # `pi` + `nixpkgs`: the agent and the tools it
#                                # shells out to (git, gh, jq, chromium, nono, ...)
#   pi-update pi                 # the `pi` input only, i.e. upstream stable HEAD
#   pi-update nixpkgs            # nixpkgs only
#   pi-update home-manager       # the module set
#   pi-update pi nixpkgs         # explicit, same as the default
#   pi-update -- -b backup       # args after `--` go to `home-manager switch`
#
# Arguments before `--` are forwarded verbatim to `nix flake update`, so any input
# name in nix/flake.nix works; the default is `pi nixpkgs`. nixpkgs is in the
# default because a pi-only bump leaves the rest stale - and `pi update`
# (sh/pi-sandbox.sh), the interactive spelling, takes no input names at all.
#
# The role is not an argument: it comes from ~/.config/dotfiles/role.env, the same
# file rebuild-env.sh reads, and is passed to rebuild-env.sh explicitly so that
# everything after `--` can belong to `home-manager switch`. `DOTFILES_ROLE` in the
# environment wins for one run: `DOTFILES_ROLE=vps pi-update`.
#
# Env overrides: PI_FLAKE_DIR, DOTFILES_REPO.
set -euo pipefail

# The checkout. $DOTFILES_REPO wins, ~/.dotfiles is the default, matching
# rebuild-env.sh and sh/env.sh. Never derived from this script's own path:
# installed to ~/.local/bin it is reached through nix store symlinks, so `dirname`
# would name ~/.local. `pwd -P` collapses the symlinked default to the checkout.
repo_anchor="${DOTFILES_REPO:-$HOME/.dotfiles}"
if ! REPO_DIR="$(cd "$repo_anchor" 2>/dev/null && pwd -P)" || [ ! -f "${REPO_DIR:-}/nix/flake.nix" ]; then
  printf 'pi-update: %s does not look like the dotfiles repo\n' "$repo_anchor" >&2
  printf '           set DOTFILES_REPO to the checkout, or create the link first:\n' >&2
  printf '               bash scripts/bootstrap.sh\n' >&2
  exit 1
fi

# Bump the lock in the tree the switch will read: ~/.dotfiles is the path the flake
# is evaluated through, so a second checkout elsewhere must not get the bump.
FLAKE_DIR="${PI_FLAKE_DIR:-}"
if [ -z "$FLAKE_DIR" ]; then
  link_nix="$HOME/.dotfiles/nix"
  if [ -e "$link_nix/flake.nix" ] && [ "$(cd "$link_nix" && pwd -P)" = "$REPO_DIR/nix" ]; then
    FLAKE_DIR="$link_nix"
  else
    FLAKE_DIR="$REPO_DIR/nix"
  fi
fi

if [ ! -e "$FLAKE_DIR/flake.nix" ]; then
  printf 'pi-update: no flake.nix under %s\n' "$FLAKE_DIR" >&2
  exit 1
fi

# Inputs first, switch flags after `--`. rebuild-env.sh re-links ~/.dotfiles before
# it evaluates, so it decides which checkout gets switched; this script only has to
# agree with it about the lock file.
inputs=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--" ]; then
    shift
    break
  fi
  inputs+=("$1")
  shift
done
switch_args=("$@")
if [ "${#inputs[@]}" -eq 0 ]; then
  inputs=(pi nixpkgs)
fi

echo "==> nix flake update ${inputs[*]} --flake $FLAKE_DIR"
nix flake update "${inputs[@]}" --flake "$FLAKE_DIR"

# rebuild-env.sh reads its first positional as the role, so resolve it here, before
# the switch flags. An unset role is left to rebuild-env.sh to complain about.
role="${DOTFILES_ROLE:-}"
role_env="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role.env"
if [ -z "$role" ] && [ -f "$role_env" ]; then
  # shellcheck disable=SC1090
  . "$role_env"
  role="${DOTFILES_ROLE:-}"
fi

echo
exec "$REPO_DIR/scripts/rebuild-env.sh" ${role:+"$role"} ${switch_args[@]+"${switch_args[@]}"}
