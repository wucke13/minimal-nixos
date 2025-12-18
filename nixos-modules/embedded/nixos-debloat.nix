# SPDX-FileCopyrightText: 2024-2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  config,
  lib,
  ...
}:

let
  cfg = config.zorn.debloat;

  /*
    Each option value is associated with a priority. Lowest numeric priority occured takes
    precedence.

    Now, `lib.mkDefaultsets the priority to 1000, `lib.mkForce` to 50 and the default is 100. Our
    `mkZornDefault` has a priority of 750, so it overrides `lib.mkDefault` settings, but it does not
    override user settings.
  */
  mkZornDefault = lib.mkOverride 750;

  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;
in
{
  options.zorn.debloat = {
    enable = lib.options.mkEnableOption "debloating of the NixOS base install";
    debloatSystemd = lib.options.mkEnableOption "systemd" // {
      default = true;
    };
    disableDocumentation = lib.options.mkEnableOption "remove man pages etc." // {
      default = true;
    };
    disableNix = lib.options.mkEnableOption "disable Nix at run-time" // {
      default = true;
    };
    disableX11Remnants = lib.options.mkEnableOption "disable Nix at run-time" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {

    nixpkgs.overlays = [
      (final: prev: {
        # https://github.com/NixOS/nixpkgs/issues/154163
        makeModulesClosure = x: prev.makeModulesClosure (x // { allowMissing = true; });

        dbus = prev.dbus.override (
          optionalAttrs cfg.disableX11Remnants {
            x11Support = false;
          }
        );

        /*
          These two tweaks saves 3 MiB of storage in the standalone initrd by butchering the
          glibc's available localization. However, they do change a package in the late nixpkgs
          bootstrapping process, effectively forcing you to recompile **every** package for this
          configuration, e.g. the official binary cache wil almost not be used. To enable quicker
          builds this setting is kept commented out for day-to-day development.
        */
        # glibcLocales = prev.glibcLocales.override {
        #   allLocales = false;
        # };
        # util-linux = prev.util-linux.override {
        #   nlsSupport = false;
        #   translateManpages = false;
        # };

        /*
          The linux kernel depends on util-linux' hexdump, util-linux depends on systemd, hence
          changing systemd implies a rebuild of the linux kernel. For deplyoment, we do not
          recommend keeping this, but it cuts development time quite  a bit to comment this in
        */
        # util-linux = prev.util-linux.override {
        #   systemd = prev.systemd;
        # };

        systemd = prev.systemd.override (
          optionalAttrs cfg.debloatSystemd {
            withAnalyze = false;
            withApparmor = false;
            withAudit = false;
            withCoredump = false;
            withCryptsetup = false;
            withDocumentation = false;
            withFido2 = false;
            withHomed = false;
            withHwdb = true; # required for nixos/modules/services/hardware/udev.nix
            withImportd = false;
            withLibBPF = false;
            withLibarchive = false;
            withLocaled = false;
            withMachined = false;
            withPasswordQuality = false;
            withRemote = false;
            withRepart = false;
            withSysupdate = false;
            withSysusers = false; # we use userborn instead
            withTpm2Tss = false;
            withVmspawn = false;
          }
        );

        /*
          Systemd and systemd minimal end up in the initrd. Hence it makes sense to build just one
          systemd that satisfies both roles. As the systemd is used as bootloader too, it no no to
          enable the relevant features for that as well.
        */
        # TODO try disabling withBootloader and withEfi to enable this optimization
        # systemdMinimal = final.systemd;
        # systemdMinimal = prev.systemdMinimal.override {
        #   withLibBPF = false;
        #   withTpm2Tss = false;
        # };
      })
    ];
    systemd.coredump.enable = !cfg.debloatSystemd;

    # disable nix and nixos-rebuild itself
    nix.enable = !cfg.disableNix;
    nix.gc.automatic = mkZornDefault false;
    nix.optimise.automatic = mkZornDefault false;
    system.activatable = true; # Unfortunately required to boot
    system.switch.enable = false;

    # disable services et al that are not strictly necessary
    programs.nano.enable = false;
    security.enableWrappers = true; # otherwise login does not work
    security.pam.services.su.forwardXAuth = lib.mkIf cfg.disableX11Remnants (lib.mkForce false); # avoid su.pam depending on X
    security.sudo.enable = false;
    services.lvm.enable = false;
    services.udev.enable = true; # otherwise mount fails due to missing /dev/disk/by-*
    services.userborn.enable = true; # the alternative is a perl activation script
    system.stateVersion = config.system.nixos.release; # TODO migrate this to standalone ramdisk?

    # disable desktop stuff
    fonts.fontconfig.enable = false;
    xdg.icons.enable = false;
    xdg.mime.enable = false;
    xdg.sounds.enable = false;

    # disable any documentation from being included
    documentation.doc.enable = false;
    documentation.enable = false;
    documentation.info.enable = false;
    documentation.man.enable = false;
    documentation.nixos.enable = false;

    # use systemd-networkd for network configuration
    networking.dhcpcd.enable = false;
    networking.firewall.enable = false;
    networking.useDHCP = false;
    systemd.network = {
      enable = true;
      networks."99-main" = {
        matchConfig.Name = "br* en* eth* wl* ww*";
        DHCP = "yes";
        networkConfig.LLMNR = false;
        networkConfig.LinkLocalAddressing = "yes";
        networkConfig.MulticastDNS = true;
      };
    };

    /*
      systemd.services.network-local-commands implicates the inclusion of a shell script,
      which in term depends on iproute2, depending ong libbpf which is quite big.
    */
    # TODO verify this has no nasty side-effects
    systemd.services.network-local-commands.enable = false;

    systemd.suppressedSystemUnits = optionals cfg.debloatSystemd [
      "unit-audit.service"
      "unit-generate-shutdown-ramfs.service"
      "unit-systemd-backlight-.service"
      "unit-systemd-fsck-.service"
      "unit-systemd-importd.service"
      "unit-systemd-mkswap-.service"
      "unit-systemd-oomd.service"
    ];

    /*
      The netboot.nix default settings add a dependency on nix itself to register store paths.
      Assuming that nix itself will not be used to modify the system running this initramfs, that
      won't be necessary.
    */
    boot.postBootCommands = lib.mkForce "";

    # only activate what we need filesystem and mass-storage wise
    boot.bcache.enable = mkZornDefault false;
    boot.swraid.enable = mkZornDefault false;
    boot.initrd.supportedFilesystems = {
      cifs = mkZornDefault false;
      bcachefs = mkZornDefault false;
      btrfs = mkZornDefault false;
      xfs = mkZornDefault false;
      zfs = mkZornDefault false;
    };
    boot.supportedFilesystems = {
      cifs = mkZornDefault false;
      bcachefs = mkZornDefault false;
      btrfs = mkZornDefault false;
      xfs = mkZornDefault false;
      zfs = mkZornDefault false;
    };
  };
}
