# The Pi coding agent: the package, the coding tools it shells out to, and the
# symlinks it needs. The agent's own flake input is declared in ../flake.nix and
# arrives here through extraSpecialArgs, so pi has exactly one lock file in this
# repository.
{
  config,
  pkgs,
  pi,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  dotfiles = "${homeDir}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  agentTools = with pkgs; [
    codegraph
    agent-browser
    ffmpeg-headless
    go
    go-tools # staticcheck et al.
    gopls
    uv # use `uv venv` / `uv pip`; nix's pip refuses store installs
    bun
    # Kernel-enforced sandbox (Landlock) for spawned commands: `nono ...`, see
    # the nono-sandbox skill installed under ~/.config/nono/packages/nolabs-ai/pi.
    # The pack itself is pulled and updated by nono (scripts/nono-packs.sh), so
    # it is not managed here; the one file this module owns under ~/.config/nono
    # is the pi profile linked below.
    nono
    rtk # rewrites/optimises tool output, state under # ~/.local/share/rtk
    # There is no smaller "headless" package to pick: headless is
    # `--headless=new` on this same binary (agent-browser passes it, plus
    # --enable-unsafe-swiftshader and, in containers, --no-sandbox).
    chromium
  ];
in
{
  home.packages = [
    # Upstream's `pi` package. Its own wrapper is what puts node, ripgrep, fd,
    # xclip and wl-clipboard on pi's PATH, so this module adds none of them.
    pi.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ]
  ++ agentTools;

  # Nix's node (pi's runtime) and the tools above fetch over TLS. Only
  # SSL_CERT_FILE is set here: the Nix installer's own snippet, which
  # home-manager sources at the end of hm-session-vars.sh
  # (`~/.nix-profile/etc/profile.d/nix.sh`), exports NIX_SSL_CERT_FILE
  # unconditionally to the host bundle, so anything set here would be lost.
  # Both bundles are real CA stores; the sandbox passes NIX_* through and
  # SSL_CERT_FILE is in the profile's allow_vars (nono/profiles/pi.json), so
  # the two survive into a sandboxed pi.
  home.sessionVariables = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  home.file = {
    ".pi".source = link "pi";
    # The generated file, not the source profile: nono expands variables in a
    # profile's filesystem paths but not in its rollback exclusions, so the
    # exclusions are resolved per machine by scripts/nono-profile-render.sh. The
    # generated file is gitignored and stignored because it holds this machine's
    # absolute paths; editing nono/profiles/pi.json requires re-running
    # scripts/nono-packs.sh (or rebuild-env.sh) before the change takes effect.
    ".config/nono/profiles/pi.json".source = link "nono/profiles/pi.generated.json";
    # Script for linking skills fro skills.txt manifest file
    ".local/bin/link-skills".source = link "scripts/link-skills.sh";
  };
}
