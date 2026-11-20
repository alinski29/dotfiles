# Pi sandbox dispatch.
#
# Sandboxed by default: every `pi` goes through nono with the pi profile, and pi
# loads its *full* extension set inside, so the guardrails extension remains the
# inner layer. There is deliberately no extension filtering here - nono's filesystem
# allowlist cannot express "deny inside an allowed directory" on Linux (Landlock is
# allow-list only), so dropping guardrails would leave nothing to gate sensitive
# files under an allowed path.
#
# --no-sandbox runs the real pi, unsandboxed and unfiltered.
#
# A `.nono-profile` file in the launch directory selects another profile for that
# session; without one, the default `pi` profile is used. See _pi_marker_profile.
#
# POSIX sh only, like sh/env.sh: sourced by both zsh and bash. Rationale:
# docs/plans/pi-sandbox-wrapper.md.

# Profile name selected by a `.nono-profile` marker in the launch directory, or
# non-zero when the marker is absent or does not hold exactly one bare name.
#
# The marker holds a *name*, never a path. Profile contents live in
# ~/.config/nono/profiles, which nono keeps read-only inside the sandbox, so a
# workspace can choose between profiles a human authored but cannot author one.
# The marker itself is agent-writable - it sits in the --allow-cwd tree - so
# anything that is not a bare name is refused instead of handed to nono: no
# paths, no `..`, no `$VARS`. A marker that fails this check leaves the caller on
# the default profile, which is the narrowest outcome and never a wider one.
_pi_marker_profile() {
  [ -f ./.nono-profile ] || return 1
  _pi_line=
  IFS= read -r _pi_line < ./.nono-profile || [ -n "$_pi_line" ] || return 1
  # Exactly one whitespace-separated field on the first line, so surrounding
  # blanks and a CRLF save are tolerated while `mono a` or `mono-a extra` are
  # refused instead of being silently trimmed into something that looks like a
  # valid name. Everything else must be a profile-name character, which is what
  # makes a path or an expansion impossible by construction.
  _pi_ifs=$IFS
  IFS=$(printf ' \t\r\n')
  set -f
  # shellcheck disable=SC2086 # deliberate field splitting
  set -- $_pi_line
  set +f
  IFS=$_pi_ifs
  [ "$#" -eq 1 ] || return 1
  case "$1" in
  '' | *[!a-z0-9-]* | -* | *-) return 1 ;;
  esac
  printf '%s\n' "$1"
}

pi() {
  # Bare `pi update` / `pi --update` mean "update via nix", not pi's own updater.
  # pi's self-update spellings (`--self`, `--all`, `--force`, `pi`, `self`) would
  # fail against a read-only store path, so they are rewritten too. `--all`
  # therefore moves only the flake pins (`pi`, `nixpkgs`); extensions are pi's own
  # and `pi update --extensions` still reaches pi. Any other invocation is Pi's own
  # CLI and must fall through untouched.
  case "${1:-}" in
  update | --update)
    case "${2:-}" in
    "" | --self | --all | --force | pi | self)
      pi-update
      return $?
      ;;
    esac
    ;;
  esac

  # Wrapper flags are consumed from the front only, so an argument containing a
  # newline (a pasted prompt) is never rebuilt or re-split. The first non-flag
  # argument ends the cluster and belongs to pi, which is why `--` passes through.
  no_sandbox=0
  rollback=--rollback
  mem=
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --no-sandbox)
      no_sandbox=1
      shift
      ;;
    --no-rollback)
      rollback=--no-rollback
      shift
      ;;
    --memory)
      if [ "$#" -lt 2 ]; then
        printf 'pi: --memory requires a size\n' >&2
        return 2
      fi
      case "$2" in
      --no-sandbox | --no-rollback | --memory | --memory=*)
        printf 'pi: --memory requires a size\n' >&2
        return 2
        ;;
      esac
      mem="$mem --memory=$2"
      shift 2
      ;;
    --memory=*)
      mem="$mem $1"
      shift
      ;;
    *)
      break
      ;;
    esac
  done

  # Buried, not merely stripped: pi ignores unknown flags silently, so a misplaced
  # wrapper flag would leave the caller believing it took effect.
  for a in "$@"; do
    case "$a" in
    --) break ;;
    --no-sandbox | --no-rollback | --memory) bad=$a ;;
    --memory=*) bad=--memory ;;
    *) continue ;;
    esac
    printf "pi: %s must appear before pi's own arguments\n" "$bad" >&2
    return 2
  done

  inert=
  if [ -n "$mem" ]; then
    inert=--memory
  fi
  if [ "$rollback" = --no-rollback ]; then
    if [ -n "$inert" ]; then
      inert="$inert and --no-rollback"
    else
      inert=--no-rollback
    fi
  fi

  if [ "$no_sandbox" -eq 1 ]; then
    if [ -n "$inert" ]; then
      printf 'pi: %s has no effect with --no-sandbox\n' "$inert" >&2
      return 2
    fi
    command pi "$@"
    return $?
  fi

  # Already inside a sandbox (nested shell, subagent): wrapping again would nest
  # nono in nono, and the inner run could not grant back what the outer denied.
  # NONO_CAP_FILE is what nono sets for its children.
  if [ -n "${NONO_CAP_FILE:-}" ]; then
    if [ -n "$inert" ]; then
      printf 'pi: %s has no effect inside an existing nono sandbox\n' "$inert" >&2
      return 2
    fi
    command pi "$@"
    return $?
  fi

  # Fail closed: without nono there is no sandbox, and only --no-sandbox may turn
  # the sandbox off.
  if ! command -v nono >/dev/null 2>&1; then
    printf 'pi: nono not found, refusing to run unsandboxed\n' >&2
    printf 'pi: use `pi --no-sandbox ...` if that is really what you want\n' >&2
    return 127
  fi

  # A grant on a missing path is inert, so pre-create the scratchpad - otherwise
  # pi could create it but not read anything back. 0700 because /tmp is 1777 and
  # shared. Failure is not fatal: pi loses scratch space, not the sandbox.
  install -d -m 0700 /tmp/pi-scratchpad 2>/dev/null || true

  # The profile grants /tmp/pi-editor r+w, and /editor writes one subdirectory per
  # run inside it. Pre-created so that grant is live from the first launch; /tmp
  # itself is already r+w via system_write_linux + linux_temp_read.
  install -d -m 0700 /tmp/pi-editor 2>/dev/null || true

  # The profile redirects XDG_RUNTIME_DIR to $XDG_RUNTIME_DIR/sandbox (set_vars) and
  # grants that directory via unix_socket_dir_bind, so nvim's RPC socket lands in a
  # dedicated 0700 dir instead of /run/user/$UID. The shared runtime dir holds the
  # session D-Bus, Wayland, PipeWire and agent sockets, so a recursive r+w grant on
  # it would hand the sandbox all of them. Pre-created because nvim does not create
  # stdpath("run") itself and a grant on a missing path is inert.
  _pi_rt=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  install -d -m 0700 "$_pi_rt/sandbox" 2>/dev/null || true

  # The compositor picks its socket name at runtime (wayland-0, wayland-1 after a
  # restart), which a static profile cannot know, and a stale name is what breaks
  # wl-copy/wl-paste inside the sandbox. So the profile points WAYLAND_DISPLAY at
  # the stable $_pi_rt/sandbox/wayland-0 (set_vars) and this refreshes that
  # symlink to the session's real socket on every launch. Best effort, like the
  # installs above: no Wayland means no clipboard, not a failed launch.
  _pi_wl=${WAYLAND_DISPLAY:-}
  case "$_pi_wl" in
  '') ;;
  /*) ;;
  *) _pi_wl="$_pi_rt/$_pi_wl" ;;
  esac
  if [ -n "$_pi_wl" ] && [ -S "$_pi_wl" ]; then
    ln -sfn "$_pi_wl" "$_pi_rt/sandbox/wayland-0" 2>/dev/null || true
  fi

  # --allow-cwd grants the directory pi was started in; everything sensitive under
  # it is the guardrails layer's job.
  #
  # --rollback snapshots the tracked roots so a session's file damage can be
  # restored on exit (`nono rollback restore`). It cannot undo network egress or
  # process side effects, so it complements the guardrails gate, not replaces it.
  # Excluded paths come from nono/profiles/pi.json, rendered per machine into
  # pi.generated.json by scripts/nono-profile-render.sh (nono does not expand
  # variables in rollback exclusions itself).
  #
  # HERDR_AGENT labels the pane in herdr's agents panel; the foreground process is
  # nono, so it has to be on the nono invocation. HERDR_PROCESS_DETECTION (sh/env.sh)
  # is what makes herdr detect an agent behind a wrapper at all.
  #
  # exec, so the pane's foreground process becomes nono rather than leaving this
  # shell as a parent herdr would see first.
  # Profile selection, narrowest first: an explicit PI_SANDBOX_PROFILE (the only
  # input that may be a path, because it comes from the parent environment rather
  # than the workspace), then a `.nono-profile` marker, then the default `pi`.
  # Every anomaly - unreadable, empty, not a bare name - falls back to `pi` with a
  # warning rather than passing the value through.
  _pi_profile=${PI_SANDBOX_PROFILE:-}
  if [ -z "$_pi_profile" ] && { [ -e ./.nono-profile ] || [ -L ./.nono-profile ]; }; then
    if ! _pi_profile=$(_pi_marker_profile); then
      _pi_profile=
      printf 'pi: ./.nono-profile must hold one profile name (a-z, 0-9, -); using pi\n' >&2
    fi
  fi

  set -- --allow-cwd -- pi "$@"
  set -- --profile "${_pi_profile:-pi}" "$@"
  for m in $mem; do
    set -- "$m" "$@"
  done
  set -- "$rollback" "$@"
  set -- run "$@"

  HERDR_AGENT="${HERDR_AGENT:-pi}" exec nono "$@"
}
