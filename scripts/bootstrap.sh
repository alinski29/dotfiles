#!/usr/bin/env bash
# Bootstrap a fresh Debian, Arch, or Fedora machine for this repo.
#
#   git clone <url> ~/dotfiles && ~/dotfiles/scripts/bootstrap.sh
# or, with nothing on disk yet:
#   curl -fsSL <raw-url> | REPO_URL=<git-url> bash
#
# Seven steps, all idempotent and safe to re-run:
#   1. detect the package manager, install git + curl + certificates
#   2. install Nix, if it is missing
#   3. get this repo: reuse this checkout, reuse an existing clone, or clone REPO_URL
#   4. link the repo to ~/.dotfiles
#   5. record this machine's role and create nix/roles.nix from the example
#   6. install the distro zsh package and make it this user's login shell
#   7. print the follow-up checklist
#
# It activates nothing and never creates or fetches a secrets file; each Nix
# environment is applied afterwards by an explicit command, so a failed
# activation cannot leave you without a working shell.
set -euo pipefail

REPO_URL="${REPO_URL:-}"                # only needed when running outside a checkout
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"  # where a standalone clone lands
LINK="$HOME/.dotfiles"                  # stable path every flake resolves through
# A role is a generic word (desktop, vps, ...), never a hostname. Kept outside
# the repo so it is never committed.
ROLE="${DOTFILES_ROLE:-${1:-}}"
ROLE_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role.env"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'bootstrap: %s\n' "$*" >&2; exit 1; }

# Root is normal on a VPS; otherwise require sudo, since steps 1/2 are system-level.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "run as root, or install sudo first"
  SUDO="sudo"
fi

# `sudo ./bootstrap.sh` is a mistake worth stopping: sudo sets HOME=/root, so
# ~/.dotfiles and the role file land under /root while rebuild-env.sh later looks
# for them in the login user's home. The installer escalates by itself. Root
# *without* SUDO_USER is a real root login (common on a fresh VPS) and is left alone.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  die "invoked through sudo, which sets HOME=/root.
       Run it as $SUDO_USER instead:
         ./scripts/bootstrap.sh${ROLE:+ $ROLE}
       The Nix installer asks for sudo itself when it needs it."
fi

log "1/7 prerequisites (git, curl, ca-certificates, xz)"
# Match what the Nix installer needs, not just what this script runs: a stripped
# image can have git and curl yet lack xz-utils or ca-certificates, and then the
# installer fails halfway.
need_pkgs=0
for c in git curl xz; do
  command -v "$c" >/dev/null 2>&1 || need_pkgs=1
done
[ -e /etc/ssl/certs/ca-certificates.crt ] || [ -e /etc/pki/tls/certs/ca-bundle.crt ] || need_pkgs=1
if [ "$need_pkgs" -eq 0 ]; then
  echo "    git, curl, xz and certificates already present"
else
  if command -v apt-get >/dev/null 2>&1; then
    # Minimal Debian images often lack xz and ca-certificates, both needed by the
    # Nix installer.
    $SUDO apt-get update
    $SUDO apt-get install -y git curl ca-certificates xz-utils
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Sy --needed --noconfirm git curl ca-certificates xz
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y git curl ca-certificates xz
  else
    die "no apt-get, pacman, or dnf found; install git and curl, then re-run"
  fi
fi

log "2/7 Nix"
if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
  echo "    Nix already installed"
else
  # Determinate's installer supports Debian and Arch hosts, sets up the daemon,
  # enables nix-command + flakes in /etc/nix/nix.conf, and adds /nix/... to the
  # PATH of new login shells. Its one hard requirement is an init system: it needs
  # systemd to run nix-daemon, or --init none in a container/CI host, and a
  # root-only install cannot apply home-manager for a normal user.
  install_args=(install --no-confirm)
  if [ ! -d /run/systemd/system ]; then
    if [ "${BOOTSTRAP_ALLOW_ROOT_ONLY_NIX:-0}" = "1" ]; then
      echo "    no systemd: installing root-only Nix (--init none)"
      install_args=(install linux --init none --no-confirm)
    else
      die "no systemd here, so the installer cannot set up nix-daemon.
       Enable systemd on this host and re-run (recommended), or accept that
       only root can use Nix:
         BOOTSTRAP_ALLOW_ROOT_ONLY_NIX=1 bash $0
       A root-only install cannot apply home-manager to a normal login user."
    fi
  fi
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- "${install_args[@]}"
fi

# The installer only updates future login shells; make nix usable in this one.
if ! command -v nix >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
command -v nix >/dev/null 2>&1 || die "nix still not on PATH; open a new shell and re-run"

# Flakes cannot be probed through `nix config show`: Determinate Nix enables them
# without reporting an `experimental-features` line, and a cleared setting prints
# nothing either, so an absent line is meaningless. Probe the behaviour instead -
# one real flake operation against a path that cannot exist. Output is captured
# rather than piped because `set -o pipefail` would inherit nix's non-zero status.
flake_probe="$(nix flake metadata ./bootstrap-flakes-probe 2>&1 || true)"
case "$flake_probe" in
  *"experimental Nix feature"*)
    cat >&2 <<'WARN'
bootstrap: warning: Nix here has the `flakes` feature disabled.
  Determinate Nix enables it by default; an older non-Determinate Nix may not.
  On Determinate Nix put overrides in /etc/nix/nix.custom.conf - never in
  /etc/nix/nix.conf, which Determinate manages. Elsewhere, in /etc/nix/nix.conf:
      experimental-features = nix-command flakes
WARN
    ;;
esac

log "3/7 this repo"
# Prefer the checkout this script lives in. BASH_SOURCE is unset when the script
# arrives through `curl | bash`, so without a source path there is no checkout to
# prefer and it goes straight to the clone.
self_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P || true)"
fi
if [ -n "$self_dir" ] && [ -e "$self_dir/nix/flake.nix" ]; then
  REPO_DIR="$self_dir"
  echo "    using this checkout"
elif [ -e "$REPO_DIR/nix/flake.nix" ]; then
  echo "    reusing the clone at $REPO_DIR"
else
  [ -n "$REPO_URL" ] || die "no checkout here and REPO_URL is unset; run: REPO_URL=<git-url> bash bootstrap.sh"
  git clone "$REPO_URL" "$REPO_DIR"
fi

log "4/7 linking $LINK"
# The flakes resolve config through ~/.dotfiles, so this path must be identical on
# every machine. `ln -sfn` would nest the link *inside* an existing real directory,
# so a stale non-symlink ~/.dotfiles must be reported, not silently mangled.
if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
  die "$LINK exists and is not a symlink; move it aside (mv $LINK $LINK.bak) and re-run"
fi
ln -sfn "$REPO_DIR" "$LINK"
ls -ld "$LINK"

log "5/7 role"
if [ -n "$ROLE" ]; then
  mkdir -p "$(dirname "$ROLE_ENV")"
  printf 'export DOTFILES_ROLE=%s\n' "$ROLE" > "$ROLE_ENV"
  echo "    $ROLE_ENV -> $ROLE"
else
  echo "    DOTFILES_ROLE unset, skipping. Write it, then re-run:"
  echo "      echo 'export DOTFILES_ROLE=<role>' > $ROLE_ENV"
fi
# nix/roles.nix is gitignored and machine-specific, so it is never cloned. The
# template is copied once and edited by hand; the CHANGEME placeholder fails the
# build until it is.
if [ -e "$REPO_DIR/nix/roles.nix" ]; then
  echo "    $REPO_DIR/nix/roles.nix already exists"
else
  cp "$REPO_DIR/nix/roles.nix.example" "$REPO_DIR/nix/roles.nix"
  echo "    created $REPO_DIR/nix/roles.nix from the example"
fi

log "6/7 login shell (zsh)"
# The login shell stays a distro package on purpose: a Nix store shell in
# /etc/passwd can lock you out of SSH, and `chsh` refuses any shell not listed in
# /etc/shells - which a Nix profile path never is. Idempotent.
WANT_ZSH=/usr/bin/zsh
current_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
if [ "$(id -u)" -eq 0 ]; then
  echo "    running as root, leaving root's login shell alone"
elif [ "${DOTFILES_SKIP_CHSH:-0}" = "1" ]; then
  echo "    DOTFILES_SKIP_CHSH=1, leaving ${current_shell:-the login shell} alone"
elif [ "$current_shell" = "$WANT_ZSH" ]; then
  echo "    login shell is already $WANT_ZSH"
else
  if [ ! -x "$WANT_ZSH" ]; then
    if command -v apt-get >/dev/null 2>&1; then
      # Refresh first: the index can be stale by the time this step runs, and a
      # mirror that dropped the pinned revision 404s the .deb (zsh 5.9-8 is the
      # usual one). pacman and dnf resolve metadata themselves, so only apt needs
      # this.
      $SUDO apt-get update
      $SUDO apt-get install -y zsh
    elif command -v pacman >/dev/null 2>&1; then
      $SUDO pacman -Sy --needed --noconfirm zsh
    elif command -v dnf >/dev/null 2>&1; then
      $SUDO dnf install -y zsh
    else
      echo "    no apt-get, pacman, or dnf found; install zsh yourself"
    fi
  fi
  if [ -x "$WANT_ZSH" ]; then
    # As root no password is needed; a normal user running chsh directly would be
    # prompted, which cannot work unattended.
    if $SUDO chsh -s "$WANT_ZSH" "$(id -un)"; then
      echo "    login shell: ${current_shell:-unknown} -> $WANT_ZSH (next login)"
    else
      echo "    chsh failed; set it by hand: chsh -s $WANT_ZSH"
    fi
  else
    echo "    zsh did not land at $WANT_ZSH; install it, then re-run this script"
  fi
fi

log "7/7 next steps"
cat <<'EOF'

Nothing is activated yet. Next steps, in this order:

  1) Edit nix/roles.nix: set `user` to the login name on this machine, keep
     `system`, and list the modules this machine's role should get. The
     CHANGEME placeholder fails the build on purpose. Name a normal login user
     even if you are configuring the box as root over SSH.

  2) Secrets are placed by hand, never fetched. This machine's file is
       ~/.config/zsh-secrets/secrets.<role>.env
     which nix/home.nix links to $XDG_CONFIG_HOME/zsh/secrets.env. It lives
     outside the repo on purpose: never committed, never synced.
     Touch it empty if you have none; an absent file is not fatal.
     The pi agent's ~/.dotfiles/pi/agent/auth.json is the same kind of file.

  3) Get `nix` onto this shell's PATH. The installer only edits login-shell
     profiles (it cannot change a session that is already running), so
     rebuild-env.sh below would otherwise fail with `nix: command not found`:
       exec "$SHELL" -l
     or, without starting a new shell:
       . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
     Confirm with `nix --version` before continuing.

  4) Apply the configuration. The first switch on a fresh machine has to be
     allowed to move the distro's own dotfiles (~/.bashrc, ~/.profile, ...)
     aside, so pass -b backup:
       bash ~/.dotfiles/scripts/rebuild-env.sh <role> -b backup

  5) zsh was installed and set as your login shell by step 6 above, so there is
     nothing to do here. That step is deliberately limited to the distro
     package: a Nix store shell in /etc/passwd can lock you out of SSH.
     If it was skipped, do it as the user you log in as:
       sudo apt-get install -y zsh        # or: sudo pacman -S --needed zsh
       chsh -s /usr/bin/zsh               # add sudo to skip the password prompt
     Recovery if a login shell ever breaks: ssh -t <host> bash

  6) Log out and back in, confirm with `echo $SHELL`, then start herdr. Panes
     spawn $SHELL, so every pane picks up zsh from here on.

Later, to move this flake's inputs (`pi` and `nixpkgs`) and switch:
       bash ~/.dotfiles/scripts/pi-update.sh
EOF
