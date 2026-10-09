#!/usr/bin/env bash
# Render the pi sandbox profile's rollback exclusions into concrete paths.
#
#   scripts/nono-profile-render.sh
#
# Called by rebuild-env.sh before the home-manager switch, and again by
# nono-packs.sh, which is what makes the profile valid on both entry points.
# Idempotent: a second run rewrites nothing.
#
# nono expands variables in `filesystem.*` paths (see capability_ext.rs: policy::
# expand_env_vars + profile::expand_vars, covering $HOME, $WORKDIR, $TMPDIR, $UID,
# $XDG_*, $NONO_* and `~/`) but NOT in `rollback.exclude_patterns` or
# `rollback.exclude_globs`: rollback_runtime.rs clones those verbatim into the
# ExclusionConfig, whose matcher uses `contains` against absolute walked paths. A
# `$HOME/...` exclusion therefore silently matches nothing. Verified on 0.79.0.
#
# The profile keeps its variables for portability; this script renders them into
# the machine-local file that ~/.config/nono/profiles/pi.json links to (see
# nix/modules/coding-agent.nix). The output holds one machine's absolute paths, so
# it is gitignored and stignored.
#
# Two deliberate differences from nono's own expansion:
#
#   * `$DOTFILES_HOME` renders to the resolved checkout (`cd ... && pwd -P`), never
#     to the `~/.dotfiles` symlink sh/env.sh exports: the rollback matcher compares
#     against walked paths, which come from canonicalized capability roots.
#   * Only the variables in the map below are substituted, so a build-time snapshot
#     of an unrelated variable cannot leak in. An unknown `$VAR` is fatal here,
#     because a pattern that renders to itself silently does nothing.
#
# Fatal for the same reason: a `~` prefix (nono does not expand it in rollback
# exclusions either) and a glob containing `/` (exclude_globs match file_name()
# alone, so a path glob can never match).
set -euo pipefail

SRC_REL="nono/profiles/pi.json"
DEST_REL="nono/profiles/pi.generated.json"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'nono-profile-render: %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is not on PATH; it is what renders the profile"

# Same anchor as rebuild-env.sh, for the same reason: copied into ~/.local/bin the
# script is reached through a chain of nix store symlinks, so walking up from its
# own path would resolve the repository to the store.
#
# `$HOME/.dotfiles` rather than `$DOTFILES_HOME`: that link is what
# nix/modules/coding-agent.nix renders its paths through, so it is the checkout
# whose file ~/.config/nono/profiles/pi.json points at.
REPO_ANCHOR="${DOTFILES_REPO:-$HOME/.dotfiles}"
if ! REPO_DIR="$(cd "$REPO_ANCHOR" 2>/dev/null && pwd -P)" || [ ! -f "${REPO_DIR:-}/$SRC_REL" ]; then
  die "$REPO_ANCHOR does not hold $SRC_REL
       set DOTFILES_REPO to the checkout, or create the link first:
           bash scripts/bootstrap.sh"
fi

SRC="$REPO_DIR/$SRC_REL"
DEST="$REPO_DIR/$DEST_REL"

log "rendering $SRC_REL -> $DEST_REL"

# Values default to nono's own: an unset XDG_DATA_HOME means $HOME/.local/share
# there too, so rendering it otherwise would exclude the wrong tree.
if jq \
  --arg home "$HOME" \
  --arg user "${USER:-$(id -un)}" \
  --arg uid "$(id -u)" \
  --arg tmpdir "${TMPDIR:-/tmp}" \
  --arg xdg_config "${XDG_CONFIG_HOME:-$HOME/.config}" \
  --arg xdg_data "${XDG_DATA_HOME:-$HOME/.local/share}" \
  --arg xdg_state "${XDG_STATE_HOME:-$HOME/.local/state}" \
  --arg xdg_cache "${XDG_CACHE_HOME:-$HOME/.cache}" \
  --arg dotfiles "$REPO_DIR" \
  '
  def vars: {
    "HOME": $home,
    "USER": $user,
    "UID": $uid,
    "TMPDIR": $tmpdir,
    "XDG_CONFIG_HOME": $xdg_config,
    "XDG_DATA_HOME": $xdg_data,
    "XDG_STATE_HOME": $xdg_state,
    "XDG_CACHE_HOME": $xdg_cache,
    "DOTFILES_HOME": $dotfiles
  };

  # nono's own substitution is `$NAME`: no `${NAME}`, no `~/`. Unknown names are
  # left unchanged so the check below can name them.
  def render: gsub("\\$(?<v>[A-Za-z_][A-Za-z0-9_]*)"; (vars[.v] // "$\(.v)"));

  def dead:
    if test("\\$[A-Za-z_{]") then "an unexpanded variable"
    elif test("^~") then "a tilde, which nono does not expand in rollback exclusions"
    else empty end;

  # Guarded on the section existing, so a profile without rollback passes through
  # untouched rather than gaining empty arrays.
  def rendered:
    .rollback.exclude_patterns = ((.rollback.exclude_patterns // []) | map(render))
    | .rollback.exclude_globs = ((.rollback.exclude_globs // []) | map(render))
    | [.rollback.exclude_patterns[] | select(dead)] as $dead_patterns
    | [.rollback.exclude_globs[] | select(dead)] as $dead_globs
    | [.rollback.exclude_globs[] | select(contains("/"))] as $path_globs
    | if ($dead_patterns + $dead_globs + $path_globs | length) > 0 then
        error("rollback exclusions that can never match:\n" + (
          [ ($dead_patterns[] | "  exclude_patterns: \(.) - \(dead)"),
            ($dead_globs[] | "  exclude_globs: \(.) - \(dead)"),
            ($path_globs[] | "  exclude_globs: \(.) - has a /, but a glob is matched against the filename only") ]
          | join("\n")))
      else . end;

  if .rollback then rendered else . end
  ' "$SRC" > "$DEST.tmp"; then
  if [ -f "$DEST" ] && cmp -s "$DEST.tmp" "$DEST"; then
    rm -f "$DEST.tmp"
    echo "    already up to date"
  else
    mv "$DEST.tmp" "$DEST"
    echo "    written"
  fi
else
  rm -f "$DEST.tmp"
  die "$SRC_REL has rollback exclusions that cannot be rendered"
fi
