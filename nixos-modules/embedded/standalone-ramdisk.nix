# SPDX-FileCopyrightText: 2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

/*
  Enable to build a fully self-contained initrd

  Mechanism (inspired by and partially copied from `nixos/modules/installer/netboot/netboot.nix`):
    - create squashfs with all necessary store paths
    - append that squashfs image behind the original initrd
    - make `/nix/store` an overlayfs mount
      - lower dir is the squashfs
      - upper dir is a tmpfs
*/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.zorn.boot.standaloneInitramdisk;

  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") {
    inherit lib pkgs;
  };

  /*
    A QEMU specifically tailored to execute this initramfs. It only contains the relevant target
    architectures, and no support for graphical or audio stuff.
  */
  # TODO fix this thing
  qemuForThisConfig =
    (pkgs.buildPackages.qemu.override {
      guestAgentSupport = true;
      numaSupport = true;
      seccompSupport = true;
      alsaSupport = false;
      pulseSupport = false;
      pipewireSupport = false;
      sdlSupport = false;
      jackSupport = false;
      gtkSupport = false;
      vncSupport = false;
      smartcardSupport = false;
      spiceSupport = false;
      ncursesSupport = true;
      usbredirSupport = false;
      xenSupport = false;
      cephSupport = false;
      glusterfsSupport = false;
      openGLSupport = false;
      rutabagaSupport = false;
      virglSupport = false;
      libiscsiSupport = true;
      smbdSupport = false;
      tpmSupport = false;
      uringSupport = true;
      canokeySupport = false;
      capstoneSupport = true;
      pluginsSupport = true;
      hostCpuTargets = [ "${pkgs.stdenv.hostPlatform.qemuArch}-softmmu" ];
    }).overrideAttrs
      (_: {
        postInstall = ":";
      });

  qemuCmd =
    (
      if cfg.useTailoredQemu then
        qemu-common.qemuBinary qemuForThisConfig
      else
        lib.attrsets.getAttr pkgs.stdenv.hostPlatform.system {
          # counterintuitively, the default cpu of qemu-system-aarch64 is an Cortex-A15 (32
          # bit only)
          aarch64-linux = "qemu-system-aarch64 -machine virt -cpu neoverse-n2";

          armv7l-linux = "qemu-system-arm -machine virt";

          powerpc64-linux = "qemu-system-ppc64 -machine ppce500 -cpu e6500";

          x86_64-linux = "qemu-system-x86_64 -enable-kvm";
        }
    )
    + lib.strings.optionalString (
      pkgs.stdenv.hostPlatform.isPower || pkgs.stdenv.hostPlatform.isx86
    ) " -append 'console=${qemu-common.qemuSerialDevice}'";

  /*
    NixOS now uses a Rust based program for early system intialization, `nixos-init`. It needs to
    find the system closure (e.g. the path to `my-configuraton.config.system.build.toplevel`) in
    order to set up everything for stage 2 from the boot process. To discover the system closure,
    `nixos-init` looks at the `init=` parameter in the kernel cmdline (e.g. `/proc/cmdline`), which
    points to the `init` binary (usually from systemd) which resides within the `toplevel` store
    path.

    However, it is unfeasible for the user of a standalone ramdisk to have to bring a long complex
    store path as `init=` value to the kernel cmdline, imagine having to type that in a U-Boot
    shell! To avoid this inconvenience, we fake `/proc/cmdline` via a bind-mount in the corresponding
    systemd units running `nixos-init` during early boot.
  */
  fakeProcCmdline = pkgs.writeTextFile {
    name = "fake-proc-cmdline";
    text = ''
      init=${config.specialisation.squashfs-toplevel.configuration.system.build.toplevel}/init
    '';
  };
  nixosInitServices = [
    "initrd-find-etc"
    "initrd-find-nixos-closure"
    "initrd-nixos-activation"
    "initrd-switch-root"
  ];
in
{
  options.zorn.boot.standaloneInitramdisk = {
    enable = lib.options.mkEnableOption "generation of a standalone initRamdisk";
    useTailoredQemu = lib.options.mkEnableOption "use a QEMU tailored for our needs" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Fake the `init=/nix/store/*/init` argument to the tolevel closure in the kernel cmdline
    boot.initrd.systemd.services = lib.attrsets.genAttrs nixosInitServices (serviceName: {
      serviceConfig.BindReadOnlyPaths = "${fakeProcCmdline}:/proc/cmdline";
    });
    boot.initrd.systemd.storePaths = [ fakeProcCmdline ];
    system.nixos-init.enable = true; # faking via /proc/cmdline only works with `nixos-init`

    /*
      The standalone ramdisk contains a squashfs with the system's
      `my-configuraton.config.system.build.toplevel`. However, at the time when that squashfs is
      mounted, both initrd and kernel are already loaded. Hence it does not make sense to include
      them in the squashfs, they are redundant. Thus we create a specialisation of the current
      configuration with all the unnecessary things removed, in order to get a smaller squashfs.
    */
    specialisation.squashfs-toplevel.configuration = {
      boot.kernel.enable = false;
      boot.initrd.enable = false;

      # TODO remove this hack once https://github.com/NixOS/nixpkgs/issues/467069 is fixed
      system.build.kernel.config = {
        isSet = _: false;
      };
    };

    fileSystems."/" = {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };

    # Mount the squashfs containing the fully populated nix-store
    fileSystems."/nix/.ro-store" = lib.mkImageMediaOverride {
      fsType = "squashfs";
      device = "../nix-store.squashfs";
      options = [
        "loop"
      ]
      ++ lib.optional (config.boot.kernelPackages.kernel.kernelAtLeast "6.2") "threads=multi";
      neededForBoot = true;
    };

    fileSystems."/nix/.rw-store" = lib.mkImageMediaOverride {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };

    fileSystems."/nix/store" = lib.mkImageMediaOverride {
      overlay = {
        lowerdir = [ "/nix/.ro-store" ];
        upperdir = "/nix/.rw-store/store";
        workdir = "/nix/.rw-store/work";
      };
      neededForBoot = true;
    };

    boot.loader.systemd-boot.enable = false;
    boot.loader.grub.enable = false;

    boot.initrd.availableKernelModules = [ "squashfs" ];

    boot.initrd.kernelModules = [ "loop" ];

    /*
      This is an NixOS internal information about the system, closing in kernel and
      bootloader --- but we don't need it in the initrd.
    */
    boot.bootspec.enable = false;

    # Create the initrd
    system.build.standaloneRamdisk = pkgs.buildPackages.makeInitrdNG {
      inherit (config.boot.initrd) compressor;
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents = [
        {
          source = config.system.build.squashfsStore;
          target = "/nix-store.squashfs";
        }
      ];
    };

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore =
      pkgs.buildPackages.callPackage (pkgs.path + "/nixos/lib/make-squashfs.nix")
        {
          storeContents = [ config.specialisation.squashfs-toplevel.configuration.system.build.toplevel ];
          comp = "zstd";
        };

    /*
      A primitive QEMU runner

      Intentionally impure (requiring `qemu-system-*` binaries to be already on the `$PATH`) to save
      compile time
    */
    system.build.standaloneRamdiskVm = pkgs.pkgsBuildBuild.writeShellApplication {
      name = "run-${config.system.name}-vm";
      text = ''
        # QEMU leaves the terminal in an unclean state upon exit.
        # See https://github.com/cirosantilli/linux-kernel-module-cheat/issues/110
        trap 'tput smam' EXIT

        echo 'launching QEMU'
        ${qemuCmd} \
          -m size=1G \
          -kernel ${config.system.build.toplevel}/kernel \
          -initrd ${config.system.build.standaloneRamdisk}/initrd \
          -netdev user,id=n1 -device virtio-net-pci,netdev=n1 \
          -nographic \
          "''${@}"
      '';
    };
  };
}
