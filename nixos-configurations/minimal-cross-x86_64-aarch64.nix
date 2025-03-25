{ lib, ... }:

{

  imports = [ ./minimal.nix ];

  config = {
    nixpkgs.buildPlatform = lib.mkForce "x86_64-linux";
    nixpkgs.hostPlatform = lib.mkForce "aarch64-linux";
  };
}
