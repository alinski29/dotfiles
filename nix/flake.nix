{
  description = "Role-based home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # master pairs with nixpkgs-unstable; the release-* branches track their own
    # release nixpkgs and are not tested against unstable.
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The Pi agent, straight from upstream. It wraps its own nodejs_22 + fd + ripgrep + clipboard and *exports* PATH for everything it spawns.
    pi = {
      url = "github:earendil-works/pi/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      pi,
    }:
    let
      inherit (nixpkgs) lib;
      # The per-machine manifest. Not in git, and that is the point: it is the
      # only place a login name, an architecture or a module list is written,
      # while this repository is public. Copy roles.nix.example to roles.nix on a
      # new machine; rebuild-env.sh reads the same file through the `roles` output
      # below.
      roles =
        if builtins.pathExists ./roles.nix then
          import ./roles.nix
        else
          throw ''
            nix/roles.nix is missing.

            It is deliberately not in git. On a new machine, from the repo root:
              cp nix/roles.nix.example nix/roles.nix
            then set `user`, `system` and `modules` for that machine's role.
          '';

      # A role is a generic word you choose (desktop, vps, ...), never a real
      # hostname. Two machines that should be configured alike share one role.
      mkHome =
        role:
        {
          user,
          system,
          modules ? [ ],
        }:
        if user == "CHANGEME" then
          throw "nix/roles.nix: role '${role}' still has the placeholder user. Set the real login name."
        else
          home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs { inherit system; };
            modules = [ ./home.nix ] ++ modules;
            extraSpecialArgs = { inherit user role pi; };
          };
    in
    {
      homeConfigurations = lib.mapAttrs' (
        role: cfg: lib.nameValuePair "${cfg.user}@${role}" (mkHome role cfg)
      ) roles;

      # The login user per role, so rebuild-env.sh can name the output without
      # guessing: `rebuild-env.sh vps` runs on another machine's behalf and must not
      # assume the invoking user. `nix flake check` prints "unknown flake output
      # 'roles'" for this; it is a custom output, the warning is cosmetic.
      roles = lib.mapAttrs (_: cfg: { inherit (cfg) user; }) roles;

      # The home-manager CLI, pinned to the same revision this flake locks, so
      # rebuild-env.sh never has to hardcode a version string that could drift from
      # the one the configuration was actually built with.
      packages = lib.genAttrs (lib.unique (lib.mapAttrsToList (_: cfg: cfg.system) roles)) (system: {
        home-manager = home-manager.packages.${system}.home-manager;
      });
    };
}
