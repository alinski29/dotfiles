#!/usr/bin/env bash
# Re-link ~/.dotfiles and apply the home-manager configuration for a role.
#
#   scripts/rebuild-env.sh                 # this machine, role from role.env
#   scripts/rebuild-env.sh desktop         # explicit role
#   scripts/rebuild-env.sh vps -b backup   # another role's configuration
#   scripts/rebuild-env.sh --update desktop         # move every flake input first
#   scripts/rebuild-env.sh --update=nixpkgs         # move one input (role from role.env)
#   scripts/rebuild-env.sh --update=pi,nixpkgs vps  # several, comma-separated
#
# Any extra arguments are passed straight to `home-manager switch`, so `-b backup`
# works for the first switch on a machine that still has hand-made symlinks. One
# step precedes the switch (scripts/nono-profile-render.sh, because the switch
# links ~/.config/nono/profiles/pi.json to the file it renders) and two follow it:
# scripts/link-skills.sh --global materialises the global agent skills listed in
# .agents/global-skills.txt, and scripts/nono-packs.sh provisions the nono pack
# the pi sandbox profile extends.
#
# The checkout is $DOTFILES_REPO when set, ~/.dotfiles otherwise. It never walks
# up from its own path: the ~/.local/bin copy home-manager installs is reached
# through a chain of nix store symlinks, so that would resolve to ~/.local.
#
# A role is a generic word (desktop, vps, ...), never a hostname, and must be a key
# in nix/roles.nix. That file is deliberately not in git, so the flake is
# referenced with `path:` (a plain git flake ref cannot see untracked files), and
# the copy is limited to nix/ (~30KB) rather than the 1.7G working tree.
#
# Updating is opt-in: without `--update` the switch applies whatever nix/flake.lock
# already pins, so rebuilding a working machine cannot silently pull new revisions
# (`git -C <repo> diff nix/flake.lock` undoes a bump). `home-manager switch
# --rollback` is not a substitute - it rolls back a profile generation, not the
# lock that generation was built from.
#
# The symlink is refreshed first because nix/home.nix resolves every path through
# ~/.dotfiles: a stale link would make the switch read paths that no longer exist.
set -euo pipefail

LINK="$HOME/.dotfiles"
FLAKE="path:$LINK/nix"

# Per-machine role, gitignored so it is never committed. It is NOT prevented
# from syncing: the whole checkout, nix/roles.nix included, travels by Syncthing
# on this setup, so editing it on one machine can overwrite another's copy. Keep
# each role's block correct for *that* machine.
#   echo 'export DOTFILES_ROLE=desktop' > ~/.config/dotfiles/role.env
ROLE_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role.env"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'rebuild-env: %s\n' "$*" >&2; exit 1; }

# The checkout to link and switch. `cd ... && pwd -P` collapses a symlinked anchor
# to the real checkout, so the `ln -sfn` below cannot become self-referential when
# the anchor and $LINK are the same path. nix/flake.nix is the marker: a wrong
# anchor is refused *before* the re-link that repoints ~/.dotfiles.
repo_anchor="${DOTFILES_REPO:-$LINK}"
if ! REPO_DIR="$(cd "$repo_anchor" 2>/dev/null && pwd -P)" || [ ! -f "${REPO_DIR:-}/nix/flake.nix" ]; then
  die "$repo_anchor does not look like the dotfiles repo
       set DOTFILES_REPO to the checkout, or create the link first:
           bash scripts/bootstrap.sh"
fi

# Determinate Nix, like the upstream installer, edits login-shell profiles only.
# A shell that predates the install has no `nix` on PATH, which would surface as
# "nix: command not found" from inside the flake evaluation. Source that snippet.
NIX_DAEMON_SH=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
if ! command -v nix >/dev/null 2>&1 && [ -e "$NIX_DAEMON_SH" ]; then
  # shellcheck disable=SC1090
  . "$NIX_DAEMON_SH"
fi
command -v nix >/dev/null 2>&1 || die "nix is not on PATH and $NIX_DAEMON_SH is not readable.
       Open a new login shell, or install Nix first: bash scripts/bootstrap.sh"

# `--update[=<input>[,<input>...]]` is consumed from the front, because the first
# positional is the role and everything after it belongs to `home-manager switch`
# (which has no --update of its own). No input names means `nix flake update` with
# no arguments, i.e. every input moves to current HEAD.
UPDATE=0
update_inputs=()
role_positional=1
while [ "$#" -gt 0 ]; do
  case "$1" in
  --update) UPDATE=1 ;;
  --update=*)
    UPDATE=1
    old_ifs="$IFS"
    IFS=,
    # shellcheck disable=SC2086  # comma-splitting the list is the point
    for input in ${1#--update=}; do update_inputs+=("$input"); done
    IFS="$old_ifs"
    ;;
  --) role_positional=0; shift; break ;;
  -*) die "flags must come before the role, and the role is not optional here:
       scripts/rebuild-env.sh --update <role> $*
       or, with $ROLE_ENV set:  scripts/rebuild-env.sh -- $*" ;;
  *) break ;;
  esac
  shift
done

# `--update` is only read from the front; anywhere later it would silently become
# a `home-manager switch` argument (which has no such flag), so say so.
for arg in "$@"; do
  case "$arg" in
  --update | --update=*) die "--update must come first, before the role:
       scripts/rebuild-env.sh --update <role> $*" ;;
  esac
done

if [ "$role_positional" -eq 1 ] && [ "$#" -gt 0 ]; then
  ROLE="$1"
  shift
elif [ -f "$ROLE_ENV" ]; then
  # shellcheck disable=SC1090
  . "$ROLE_ENV"
  ROLE="${DOTFILES_ROLE:-}"
  [ -n "$ROLE" ] || die "$ROLE_ENV does not set DOTFILES_ROLE"
else
  die "no role given, and $ROLE_ENV does not exist
       pass one:  scripts/rebuild-env.sh <role>
       or write:  echo 'export DOTFILES_ROLE=<role>' > $ROLE_ENV"
fi

log "linking $LINK -> $REPO_DIR"
# Same hazard as bootstrap.sh: `ln -sfn` would nest the link inside an existing
# real directory instead of replacing it.
if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
  die "$LINK exists and is not a symlink; move it aside (mv $LINK $LINK.bak) and re-run"
fi
ln -sfn "$REPO_DIR" "$LINK"
ls -ld "$LINK"

# After the re-link, so the bump lands in the checkout `path:$LINK/nix` resolves
# to, and before anything evaluates the flake. `nix flake update` rewrites
# flake.lock in place for a `path:` ref, so no cd is needed.
if [ "$UPDATE" -eq 1 ]; then
  if [ "${#update_inputs[@]}" -eq 0 ]; then
    log "nix flake update (every input) --flake $FLAKE"
  else
    log "nix flake update ${update_inputs[*]} --flake $FLAKE"
  fi
  nix flake update ${update_inputs[@]+"${update_inputs[@]}"} --flake "$FLAKE"
  echo "    revert: git -C $REPO_DIR diff nix/flake.lock"
fi

# The login user comes from the manifest, not `id -un`: `rebuild-env.sh vps` runs
# on another machine's behalf, where the invoking user is the wrong answer.
log "resolving the user for role '$ROLE' from nix/roles.nix"
# Stdout only, on purpose: `--raw` output is used verbatim as the username, and
# Nix prints warnings to stderr that would otherwise glue onto it. On failure the
# eval repeats with stderr shown, because the exit status alone cannot tell a
# missing role apart from a genuine flake error.
if ! USER_OF_ROLE="$(nix eval --raw --apply "roles: roles.\"$ROLE\".user" "$FLAKE#roles")"; then
  eval_err="$(nix eval --raw --apply "roles: roles.\"$ROLE\".user" "$FLAKE#roles" 2>&1 || true)"
  case "$eval_err" in
    *"attribute '$ROLE' missing"*)
      die "role '$ROLE' is not in nix/roles.nix (see nix/roles.nix.example)" ;;
    *"experimental Nix feature"*)
      die "nix is installed but the required experimental features are off:
$eval_err
       Determinate Nix enables nix-command and flakes by default, so this is a
       non-Determinate Nix. On Determinate Nix write overrides to
       /etc/nix/nix.custom.conf, never to /etc/nix/nix.conf. Elsewhere add to
       /etc/nix/nix.conf:
           experimental-features = nix-command flakes" ;;
  esac
  die "nix eval failed for $FLAKE#roles:
$eval_err"
fi
CONFIG="$USER_OF_ROLE@$ROLE"
echo "    $CONFIG"

log "login shell"
# Same rule as bootstrap.sh: the login shell stays a distro package, because a
# Nix store shell in /etc/passwd can lock you out of SSH and `chsh` only accepts
# shells in /etc/shells. This only chsh-es; installing the package is
# bootstrap.sh's job. Idempotent, and a no-op after the first rebuild. Kept above
# the switch so the shell is right even if the switch fails.
WANT_ZSH=/usr/bin/zsh
current_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
if [ "${DOTFILES_SKIP_CHSH:-0}" = "1" ] || [ "$(id -u)" -eq 0 ]; then
  echo "    skipped (${current_shell:-unknown})"
elif [ "$current_shell" = "$WANT_ZSH" ]; then
  echo "    already $WANT_ZSH"
elif [ -x "$WANT_ZSH" ] && command -v sudo >/dev/null 2>&1; then
  # Unlike bootstrap.sh this runs on an already-provisioned machine, so the shell
  # may never have been zsh: say so rather than failing quietly.
  if sudo chsh -s "$WANT_ZSH" "$(id -un)"; then
    echo "    ${current_shell:-unknown} -> $WANT_ZSH (takes effect on the next login)"
  else
    echo "    chsh failed; set it by hand: chsh -s $WANT_ZSH"
  fi
elif [ -x "$WANT_ZSH" ]; then
  echo "    no sudo; set it by hand: chsh -s $WANT_ZSH"
else
  echo "    $WANT_ZSH is missing; install the distro package, then re-run:"
  echo "      bash ~/.dotfiles/scripts/bootstrap.sh"
fi

# Before the switch, because the switch links the rendered profile:
# ~/.config/nono/profiles/pi.json -> nono/profiles/pi.generated.json. nono expands
# variables in a profile's filesystem paths but not in its rollback exclusions,
# so those are resolved here - see nono-profile-render.sh.
log "rendering the pi profile's rollback exclusions"
DOTFILES_REPO="$REPO_DIR" "$REPO_DIR/scripts/nono-profile-render.sh"

log "home-manager switch --flake $FLAKE#$CONFIG $*"
# The CLI comes from this flake's own lock rather than PATH, so tool and config
# can never be different revisions. Deliberately not `exec`ed: the provisioning
# steps below must run after the switch has written its symlinks.
nix run "$FLAKE#home-manager" -- switch --flake "$FLAKE#$CONFIG" "$@"

# Global agent skills. The switch above created the ~/.agents/skills.txt symlink
# this reads its desired set from (nix/home.nix links it to the repo's
# .agents/global-skills.txt).
log "linking global agent skills into ~/.agents/skills"
DOTFILES_HOME="$LINK" "$REPO_DIR/scripts/link-skills.sh" --global

# After the switch, never before: ~/.pi and the pi profile are home-manager
# symlinks, and on a fresh machine neither exists until the switch has run, so an
# earlier pull would make nono's wiring create real files where home-manager wants
# symlinks. Running it last also keeps a failed pull from aborting a good switch.
log "provisioning the nono pack for the pi sandbox"
"$REPO_DIR/scripts/nono-packs.sh"
