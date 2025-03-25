{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      lib = import ./lib.nix nixpkgs.lib;
    in
    {
      overlays.default = import ./overlay.nix;

      # NixOS Configurations
      nixosConfigurations = (
        lib.attrsets.mapAttrs (
          name: nixFile:
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs;
              flakeRoot = ./.;
            };
            modules = [
              nixFile
              {
                nixpkgs.overlays = [ self.overlays.default ];
                system.name = lib.mkDefault name;
              }
            ];
          }
        ) (lib.zornlib.nixFilesToAttrset ./nixos-configurations)
      );
    }
    // (inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        # nixpkgs instance for the current sytem with our overlay applied
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        # generate local packages + goodies
        packages = pkgs.zornpkgs;

        # generate deploy-scripts
        apps = {
          update-flake-lock = inputs.flake-utils.lib.mkApp rec {
            name = "update-flake-lock";
            drv = pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [
                pkgs.coreutils-full
                pkgs.git
                pkgs.nixStable
              ];
              text = ''
                nix flake update --commit-lock-file
                COMMIT_TITLE="chore: update flake.lock"
                COMMIT_BODY=$(git log -1 --pretty=%B | tail -n +3)
                COMMIT_MESSAGE="$COMMIT_TITLE"$'\n\n'"$COMMIT_BODY"
                git commit --amend --signoff --message="$COMMIT_MESSAGE"
              '';
            };
          };
        };

        # for `nix fmt`
        formatter = treefmtEval.config.build.wrapper;

        # for `nix flake check`
        checks = {
          formatting = treefmtEval.config.build.check self;
        };
      }
    ));
}
