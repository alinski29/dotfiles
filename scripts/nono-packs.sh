#!/usr/bin/env bash
# Install the nono pack that the pi sandbox profile extends, and keep the entry
# the pack's wiring writes into pi's settings host-neutral.
#
#   scripts/nono-packs.sh
#
# Called at the end of rebuild-env.sh, after the switch has linked ~/.pi and
# ~/.config/nono/profiles/pi.json. Renders the profile first, so a hand-edited
# profile is picked up by running this script alone. The pack tracks the registry
# rather than a pinned version; what is guaranteed is a resolvable profile and no
# machine-specific absolute path left in a file every machine syncs.
#
# Fatal: the pack must install and the profile must resolve afterwards - without
# the pack the profile's `extends` target is missing and the pi wrapper fails
# closed. Warning only: the settings rewrite, which is repo hygiene.
set -euo pipefail

PACK="nolabs-ai/pi"
# What pi should see in settings.json. `~` is expanded by pi; $HOME and other
# variables are not, and nono's wiring writes the absolute install path, so this
# is the only portable form.
ENTRY="~/.config/nono/packages/nolabs-ai/pi"
SETTINGS="$HOME/.pi/agent/settings.json"
PROFILE="$HOME/.config/nono/profiles/pi.json"
# Same anchor as rebuild-env.sh: this script is invoked by absolute path, but the
# profile renderer it calls resolves the checkout by name rather than by walking up
# from a path that may be a store symlink. `$HOME/.dotfiles`, not `$DOTFILES_HOME`,
# because that link is what nix/modules/coding-agent.nix resolves through.
REPO_ANCHOR="${DOTFILES_REPO:-$HOME/.dotfiles}"
RENDERER="$REPO_ANCHOR/scripts/nono-profile-render.sh"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'nono-packs: %s\n' "$*" >&2; exit 1; }
warn() { printf 'nono-packs: warning: %s\n' "$*" >&2; }

command -v nono >/dev/null 2>&1 || die "nono is not on PATH; run a home-manager switch first"

# First, so a hand-edited profile is rendered even on a standalone run. Fatal:
# the link the switch created points at the file this writes.
[ -x "$RENDERER" ] || die "$RENDERER is not executable
       set DOTFILES_REPO to the checkout if ~/.dotfiles is not it"

log "rendering the pi profile's rollback exclusions"
"$RENDERER"

log "installing or updating the $PACK pack"
# Unconditional and idempotent: a current install prints "already at <version>"
# and exits 0, a fresh machine installs, a newer release is taken.
nono pull "$PACK" || die "nono pull $PACK failed"

log "validating $PROFILE"
# By absolute path, never by name: `profile validate` takes a FILE, and a bare
# `pi` resolves relative to the cwd - the repo's pi/ directory - and fails with
# "Profile read error ... Is a directory".
nono profile validate "$PROFILE" || die "$PROFILE is missing or invalid after pulling $PACK
       (is ~/.config/nono/profiles/pi.json linked by a home-manager switch, and
       is scripts/nono-profile-render.sh able to write its target?)"

# Every install re-runs the pack's wiring, which appends {"source": "<absolute
# pack dir>"} to pi's settings. That file is tracked in the dotfiles repo and synced
# between machines, so one host's absolute path would clobber another's. Drop every
# entry pointing at the pack (this host's path, another host's, the ~ form - all end
# in the pack's registry path) and append exactly one portable entry.
if [ ! -f "$SETTINGS" ]; then
  warn "$SETTINGS does not exist; skipping the settings rewrite"
elif ! command -v jq >/dev/null 2>&1; then
  warn "jq is not on PATH; skipping the settings rewrite"
elif jq --arg entry "$ENTRY" '
      def is_pack:
        (if type == "object" then (.source // "") else . end)
        | endswith("/nono/packages/nolabs-ai/pi");
      .packages = ((.packages // []) | map(select(is_pack | not))) + [{"source": $entry}]
    ' "$SETTINGS" > "$SETTINGS.tmp"; then
  log "normalizing the $PACK entry in $SETTINGS"
  mv "$SETTINGS.tmp" "$SETTINGS"
else
  rm -f "$SETTINGS.tmp"
  warn "could not rewrite $SETTINGS; the $PACK entry may be host-specific"
fi

# A pi package source is a literal, so the canonical entry is only correct where
# nono installs packs under ~/.config.
if [ -n "${XDG_CONFIG_HOME:-}" ] && [ "$XDG_CONFIG_HOME" != "$HOME/.config" ]; then
  warn "XDG_CONFIG_HOME is $XDG_CONFIG_HOME, so nono installs packs elsewhere; the canonical entry assumes ~/.config"
fi

log "nono packs are provisioned"
