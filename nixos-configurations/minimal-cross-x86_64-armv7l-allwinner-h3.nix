# SPDX-FileCopyrightText: 2024-2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{ lib, ... }:

{

  imports = [ ./minimal.nix ];

  config = {
    nixpkgs.buildPlatform = "x86_64-linux";
    nixpkgs.hostPlatform = "armv7l-linux";

    boot.kernelPatches = [
      {
        name = "enable-allwinner-h3-specifics";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          ARCH_SUNXI = yes;
          ARM_APPENDED_DTB = yes;
          ARM_ATAG_DTB_COMPAT = yes;
          CLK_SUNXI = yes;
          CLK_SUNXI_PRCM_SUN8I = yes;
          DWMAC_SUN8I = yes;
          I2C = yes;
          I2C_CHARDEV = yes;
          I2C_MV64XXX = yes;
          MACH_SUN8I = yes;
          MMC = yes;
          MMC_SUNXI = yes;
          PINCTRL_SUN8I_H3 = yes;
          PINCTRL_SUN8I_H3_R = yes;
          PINCTRL_SUNXI = yes;
          POWER_RESET = yes;
          POWER_SUPPLY = yes;
          REGULATOR = yes;
          REGULATOR_FIXED_VOLTAGE = yes; # for the mmc controller a regulator has to be registered
          RESET_SUNXI = yes;
          SERIAL_8250 = lib.mkForce yes;
          SERIAL_8250_CONSOLE = lib.mkForce yes;
          SERIAL_8250_DW = yes;
          SPI = yes;
          SUN8I_H3_CCU = yes;
          SUNXI_MBUS = yes;
          SUNXI_NMI_INTC = yes;
          SUNXI_RSB = yes;
          SUNXI_SRAM = yes;

          # for ethernet
          NETDEVICES = yes;
          ETHERNET = yes;
          NET_VENDOR_STMICRO = yes;
          STMMAC_ETH = yes;
          STMMAC_PLATFORM = yes;
          OF = yes;
        };
      }
    ];
  };
}
