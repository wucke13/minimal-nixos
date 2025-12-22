# SPDX-FileCopyrightText: 2024-2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
      homeConfigurations = { };
      nixosModules.default = import ./nixos-modules;
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
                pkgs.nixVersions.stable
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

        # for hydra based CI
        hydraJobs =
          (
            let
              inherit (builtins) listToAttrs;
              inherit (lib.attrsets) getAttr mapCartesianProduct;

              kernel = [
                "linux_latest"
                "linux_6_18"
                "linux_6_12"
                "linux_6_6"
                "linux_6_1"
                "linux_5_15"
                "linux_5_10"
              ];

              crossSystem = [
                "x86_64-linux"
                "i686-linux"
                "aarch64-linux"
                "armv7a-linux"
              ];
            in
            listToAttrs (
              mapCartesianProduct
                (
                  { kernel, crossSystem }:
                  let
                    p = import nixpkgs {
                      inherit system;
                      crossSystem.config = crossSystem;
                    };
                    baseKernel = getAttr kernel p;
                  in
                  {
                    name = "minimal-linux-kernel-${p.stdenv.hostPlatform.linuxArch}-${baseKernel.version}";
                    value = p.callPackage ./pkgs/minimal-linux-kernel.nix { inherit baseKernel; };
                  }
                )
                {
                  inherit kernel crossSystem;
                }
            )
          )
          // (
            let
              derivationProduct = lib.attrsets.cartesianProduct {
                configName = lib.attrsets.attrNames self.nixosConfigurations;
                output = [
                  "gdbLauncher"
                  "kernel"
                  "standaloneRamdisk"
                  "standaloneRamdiskVm"
                  "toplevel"
                ];
              };
            in
            lib.attrsets.genAttrs' derivationProduct (
              { configName, output }:
              {
                name = "${configName}-${output}";
                value = self.nixosConfigurations.${configName}.config.system.build.${output};
              }
            )
          );
      }
    ));
}
