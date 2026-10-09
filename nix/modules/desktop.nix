# Everything that only makes sense on a machine with a display.
# Configuration and environment only - deliberately no GUI *packages*.
{
  config,
  pkgs,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  dotfiles = "${homeDir}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  # A font is the exception that proves the rule: no window, no driver stack, and
  # managing it here is what makes the terminal look the same on a machine that
  # never installed CommitMono from a distro package. The package ships three
  # variants - plain, Mono and Propo - and ghostty/config.ghostty asks for the
  # plain one, whose family name is exactly "CommitMono Nerd Font".
  home.packages = with pkgs; [
    nixd
    nixfmt
  ];

  # Moved out of sh/env.sh, which every role sources: a headless box has no
  # terminal emulator and no browser, so exporting these there was a lie.
  home.sessionVariables = {
    TERMINAL = "ghostty";
    BROWSER = "zen-browser";
  };

  home.file = {
    ".config/ghostty".source = link "ghostty";
    ".config/alacritty".source = link "alacritty";
    ".config/zed".source = link "zed";
  };
}
