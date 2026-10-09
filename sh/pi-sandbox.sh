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
# POSIX sh only, like sh/env.sh: sourced by both zsh and bash. Rationale:
# docs/plans/pi-sandbox-wrapper.md.

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
  install -d -m 0700 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sandbox" 2>/dev/null || true

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
  set -- --allow-cwd -- pi "$@"
  set -- --profile "${PI_SANDBOX_PROFILE:-pi}" "$@"
  for m in $mem; do
    set -- "$m" "$@"
  done
  set -- "$rollback" "$@"
  set -- run "$@"

  HERDR_AGENT="${HERDR_AGENT:-pi}" exec nono "$@"
}
