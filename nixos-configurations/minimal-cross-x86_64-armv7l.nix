# SPDX-FileCopyrightText: 2024-2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{ ... }:

{

  imports = [ ./minimal.nix ];

  config = {
    nixpkgs.buildPlatform = "x86_64-linux";
    nixpkgs.hostPlatform = "armv7l-linux";
  };
}
