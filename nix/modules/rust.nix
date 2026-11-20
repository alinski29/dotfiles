# Rust: a compiler and cargo.
#
# No C toolchain is listed here on purpose. ../home.nix already installs
# stdenv.cc (the *wrapped* gcc, which is what a Rust crate's cc/linker step
# needs) for every Linux role, so adding pkgs.gcc as well would put a second,
# unwrapped gcc earlier on PATH and silently drop the wrapper's NIX_LDFLAGS.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rustc
    cargo
    clippy
    rustfmt
  ];
}
