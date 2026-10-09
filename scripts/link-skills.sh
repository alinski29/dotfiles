#!/usr/bin/env bash
set -euo pipefail

# link-skills - symlink skills from dotfiles into target directory.
#
#   link-skills                  # interactive menu (always)
#   link-skills skill-a skill-b  # link specific skills, no menu
#   link-skills -t /path         # link to explicit target
#   link-skills --global         # reconcile ~/.agents/skills from the repo list
#
# --global is what scripts/rebuild-env.sh runs: never interactive, reads the
# desired set from $DOTFILES_HOME/.agents/global-skills.txt (also linked to
# ~/.agents/skills.txt by home-manager), and never rewrites that list.
#
# Environment: DOTFILES_HOME (default ~/.dotfiles), GLOBAL_SKILLS_DIR (default
# ~/.agents/skills).
#
# fzf state colors: green = in manifest + linked, yellow = in manifest + not
# linked, white = not in manifest.

# ~/.dotfiles is the stable link bootstrap.sh/rebuild-env.sh create and the path
# nix/home.nix resolves config through, so a moved checkout needs no edit here.
# Same default as sh/env.sh; rebuild-env.sh passes it explicitly.
DOTFILES_HOME="${DOTFILES_HOME:-$HOME/.dotfiles}"
SKILLS_SOURCE="$DOTFILES_HOME/.agents/skills"
GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-$HOME/.agents/skills}"

TARGET_DIR="$(pwd)/.agents/skills"
GLOBAL=false
TARGET_EXPLICIT=false
SKILLS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -t) TARGET_DIR="$2"; TARGET_EXPLICIT=true; shift 2 ;;
    --global|-g) GLOBAL=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *)  SKILLS+=("$1"); shift ;;
  esac
done

if [[ "$GLOBAL" == true ]]; then
  [[ "$TARGET_EXPLICIT" == true ]] && { echo "Error: --global and -t are mutually exclusive" >&2; exit 1; }
  TARGET_DIR="$GLOBAL_SKILLS_DIR"
fi

die()  { echo "Error: $*" >&2; exit 1; }
info() { echo "→ $*"; }

has_cmd() { command -v "$1" &>/dev/null; }

list_dirs() {
  local dir="$1"
  [[ -d "$dir" ]] && find "$dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' | sort
}

clean_broken_links() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local count=0
  while IFS= read -r link; do
    rm "$link"
    count=$((count + 1))
  done < <(find "$dir" -maxdepth 1 -type l ! -exec test -e {} \; -print)
  (( count > 0 )) && info "Removed $count broken symlink(s)" || true
}

is_linked() {
  local skill="$1"
  local tgt_path="$TARGET_DIR/$skill"
  [[ -L "$tgt_path" ]] && [[ "$(readlink "$tgt_path")" == "$SKILLS_SOURCE/$skill" ]]
}

link_skill() {
  local skill="$1"
  local src_path="$SKILLS_SOURCE/$skill"
  local tgt_path="$TARGET_DIR/$skill"

  [[ -d "$src_path" ]] || { echo "  Skip $skill (not in source)"; return 0; }

  if [[ -L "$tgt_path" ]] && [[ "$(readlink "$tgt_path")" == "$src_path" ]]; then
    echo "  $skill (already linked)"
    return 0
  fi

  [[ -L "$tgt_path" || -e "$tgt_path" ]] && rm -rf "$tgt_path"
  mkdir -p "$(dirname "$tgt_path")"

  if has_cmd stow; then
    stow -d "$DOTFILES_HOME/.agents" -t "$(dirname "$TARGET_DIR")" "$skill" 2>/dev/null \
      && return 0
  fi

  ln -s "$src_path" "$tgt_path"
}

unlink_skill() {
  local skill="$1"
  local tgt_path="$TARGET_DIR/$skill"
  if [[ -L "$tgt_path" ]]; then
    rm "$tgt_path"
    echo "  Unlinked $skill"
  fi
}

ANSI_GREEN=$'\033[32m'
ANSI_YELLOW=$'\033[33m'
ANSI_RESET=$'\033[0m'

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

read_manifest() {
  if [[ -f "$MANIFEST" ]]; then
    grep -v '^\s*$\|^\s*#' "$MANIFEST" || true
  fi
}

write_manifest() {
  mkdir -p "$(dirname "$MANIFEST")"
  printf '%s\n' "$@" > "$MANIFEST"
  info "Wrote manifest: $MANIFEST"
}

# In --global mode this is the repo's own global-skills.txt (reached through
# the ~/.agents/skills.txt symlink home-manager creates) and is the source of
# truth, never rewritten. A project manifest sits next to its target dir:
# <project>/.agents/skills.txt for <project>/.agents/skills.
if [[ "$GLOBAL" == true ]]; then
  MANIFEST="$DOTFILES_HOME/.agents/global-skills.txt"
else
  MANIFEST="$(dirname "$TARGET_DIR")/skills.txt"
fi

select_skills_interactive() {
  local -a available
  mapfile -t available < <(list_dirs "$SKILLS_SOURCE")

  [[ ${#available[@]} -eq 0 ]] && die "No skills found in $SKILLS_SOURCE"

  # skills already loaded globally are filtered out below
  local -a global_skills=()
  mapfile -t global_skills < <(list_dirs "$GLOBAL_SKILLS_DIR")

  local -a local_skills=()
  for skill in "${available[@]}"; do
    local is_global=false
    for g in "${global_skills[@]}"; do
      [[ "$skill" == "$g" ]] && is_global=true && break
    done
    [[ "$is_global" == false ]] && local_skills+=("$skill")
  done

  [[ ${#local_skills[@]} -eq 0 ]] && { info "All skills are globally loaded."; return 1; }

  local -a manifest_skills=()
  mapfile -t manifest_skills < <(read_manifest)

  # fzf_input entries: "<state>|<color>|<skill>"; state 1 = manifest + linked,
  # 2 = manifest + not linked, 0 = not in manifest.
  local -a fzf_input=()
  for skill in "${local_skills[@]}"; do
    local in_manifest=false
    for m in "${manifest_skills[@]}"; do
      [[ "$skill" == "$m" ]] && in_manifest=true && break
    done

    local state=0
    local color=""
    if [[ "$in_manifest" == true ]]; then
      if is_linked "$skill"; then
        state=1
        color="$ANSI_GREEN"
      else
        state=2
        color="$ANSI_YELLOW"
      fi
    fi

    fzf_input+=("${state}|${color}|${skill}")
  done

  local header=""
  if [[ ${#global_skills[@]} -gt 0 ]]; then
    header="Global (auto-loaded): $(IFS=', '; echo "${global_skills[*]}")"
  fi

  # fzf has no native pre-selection, so manifest membership is shown by color
  # and prefix only; the user toggles with TAB.
  local -a display_input=()
  for entry in "${fzf_input[@]}"; do
    IFS='|' read -r state color skill <<< "$entry"
    if [[ "$state" == "1" ]]; then
      display_input+=("${color}* ${skill}${ANSI_RESET}")
    elif [[ "$state" == "2" ]]; then
      display_input+=("${color}! ${skill}${ANSI_RESET}")
    else
      display_input+=("  ${skill}")
    fi
  done

  local selected
  selected=$(printf '%s\n' "${display_input[@]}" | fzf \
    --ansi \
    --multi \
    --no-sort \
    --header "$header" \
    --prompt "Select skills (TAB to toggle, ENTER to confirm)> " \
    --height 60% \
    --marker='*' \
    --bind 'tab:toggle+down' \
    --color='fg:white,hl:green,hl+:green:bold,info:green,prompt:green,pointer:green,spinner:green,marker:green,header:green' \
    || true)

  [[ -z "$selected" ]] && return 1

  echo "$selected" | strip_ansi | sed -E 's/^[*! ]+//' | grep -v '^$'
}

main() {
  [[ -d "$SKILLS_SOURCE" ]] || die "Skills source not found: $SKILLS_SOURCE"

  info "Source: $SKILLS_SOURCE"
  info "Target: $TARGET_DIR"

  mkdir -p "$TARGET_DIR"
  clean_broken_links "$TARGET_DIR"

  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    # Prefer the manifest when present: reconcile idempotently, user picks the
    # rest interactively.
    local -a from_manifest=()
    mapfile -t from_manifest < <(read_manifest)
    if [[ ${#from_manifest[@]} -gt 0 ]]; then
      SKILLS=("${from_manifest[@]}")
      info "Manifest: $MANIFEST (${#SKILLS[@]} skill(s))"
    elif [[ "$GLOBAL" == true ]]; then
      # Unattended setup must not silently fall through to a prompt.
      die "no global skills listed in $MANIFEST"
    else
      info "Opening selector..."
      mapfile -t SKILLS < <(select_skills_interactive) || die "No skills selected"
    fi
  fi

  [[ ${#SKILLS[@]} -eq 0 ]] && die "No skills selected"

  info "Reconciling ${#SKILLS[@]} skill(s)..."
  echo ""

  for skill in "${SKILLS[@]}"; do
    link_skill "$skill" || echo "  Failed $skill"
  done

  for existing in "$TARGET_DIR"/*/; do
    [[ -L "$existing" ]] || continue
    local name
    name=$(basename "$existing")
    local keep=false
    for s in "${SKILLS[@]}"; do
      [[ "$s" == "$name" ]] && keep=true && break
    done
    [[ "$keep" == false ]] && unlink_skill "$name"
  done

  # --global skips this: $MANIFEST is the git-tracked repo list, so a stray
  # interactive run must not shrink it.
  if [[ "$GLOBAL" != true ]]; then
    write_manifest "${SKILLS[@]}"
  fi

  info "Done."
}

main
