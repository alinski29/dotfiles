# agent-browser from upstream's prebuilt binary, not from source.
#
# nixpkgs' `agent-browser` is a rustPlatform.buildRustPackage: it compiles the
# CLI (fat LTO, ~600 crates), runs its serialised test suite, and first builds
# the Next.js dashboard that the Rust side embeds via RustEmbed. Any nixpkgs
# bump that moves rustc, stdenv or one of its inputs changes the derivation
# hash, so the cache.nixos.org copy stops matching and the machine pays for all
# of that again - 0.38.1, 0.38.2, 0.39.1 and 0.41.1 were each compiled here
# that way, and a bare `nix flake update` can force another.
#
# Upstream already ships those bytes prebuilt: the npm tarball carries
# `bin/agent-browser-linux-*`, produced by upstream's own docker build, with the
# dashboard compiled in. The `linux-musl-*` variants are statically linked, so
# they need no patchelf, no glibc and no wrapper, and the whole thing is one
# fixed-output fetch plus an install - seconds instead of tens of minutes, and
# a store path that survives every nixpkgs update.
#
# Bumping: take the version and `dist.integrity` from `npm view agent-browser
# dist-tags dist.integrity` and paste both below. The hash is the npm-published
# sha512 SRI, so it is verifiable against the registry without a rebuild.
{
  lib,
  stdenv,
  fetchurl,
  version ? "0.42.0",
  hash ? "sha512-4njBSXKDH75hu+xSOJE4msKFQPIrwcyREFgr/tfDWQ4+vWiibNvEbxA5cH3cbAFG3vJa9vhGCPV2fLp5Py6NzA==",
}:

let
  # npm publishes no per-platform packages for this version, so one 57 MiB
  # tarball carries every platform; only the matching binary is installed.
  upstreamBinary =
    {
      x86_64-linux = "linux-musl-x64";
      aarch64-linux = "linux-musl-arm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "agent-browser-bin: upstream ships no static Linux binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
    inherit hash;
  };

  # npm packaging only: there is no configure or build step.
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    # The `skills` subcommand looks for `skills/` and `skill-data/` next to
    # `bin/`, relative to the canonical exe path, so they land at $out root -
    # the same layout nixpkgs' package uses.
    install -Dm755 bin/agent-browser-${upstreamBinary} $out/bin/agent-browser
    cp -r skills skill-data $out/
    runHook postInstall
  '';

  meta = {
    description = "Headless browser automation CLI for AI agents (upstream prebuilt binary)";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "agent-browser";
  };
}
