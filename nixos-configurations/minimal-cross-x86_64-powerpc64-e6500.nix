# SPDX-FileCopyrightText: 2024-2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{ config, lib, ... }:

{

  imports = [ ./minimal.nix ];

  config = {
    nixpkgs.buildPlatform = lib.mkForce "x86_64-linux";
    nixpkgs.hostPlatform = {
      system = "powerpc64-unknown-linux-gnuabielfv1";
      gcc.cpu = "e6500";
      linux-kernel.name = "powerpc64";
      rust.rustcTarget = "powerpc64-unknown-linux-gnu"; # rust only supports elfv1

      # See https://www.kernel.org/doc/html/v5.4/powerpc/bootwrapper.html
      linux-kernel.target = "zImage";
    };

    boot.initrd.systemd.suppressedStorePaths = [
      # TODO file upstream bug report, this file doesn't exist for the powerpc systemd
      "${config.boot.initrd.systemd.package}/lib/udev/dmi_memory_id"
    ];
  };
}
