{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/netboot/netboot.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  config = {
    boot.kernelPackages = pkgs.linuxPackagesFor (
      pkgs.linuxPackages_latest.kernel.override {
        autoModules = false;
        kernelPreferBuiltin = true;
        enableCommonConfig = false; # only use our extraStructuredConfig
        defconfig = "tinyconfig";
        structuredExtraConfig = with lib.kernel; {
          # nixos nags about these
          AUTOFS_FS = yes;
          MODULES = yes;
          CRYPTO_HMAC = yes;
          CRYPTO_SHA256 = yes;
          SECCOMP = yes;

          # essentials
          BINFMT_ELF = yes;
          BINFMT_SCRIPT = yes; # otherwise shebangs wont work for systemd services
          BLK_DEV_INITRD = yes;
          CRYPTO = yes;
          CRYPTO_USER_API_HASH = yes;
          DMI = if pkgs.hostPlatform.isx86 then yes else unset;
          DMIID = if pkgs.hostPlatform.isx86 then yes else unset;
          FILE_LOCKING = yes; # otherwise libmount fails to updat the userpace mount table
          MULTIUSER = yes;
          # SMP = yes; # enable multi-core support

          KERNEL_ZSTD = yes; # compress the kernel as good as possible

          # network
          INET = yes;
          IPV6 = yes;
          NET = yes;
          NETDEVICES = yes; # otherwise systemd-resolved can't bind using SO_BINDTOIFINDEX
          PACKET = yes; # otherwise sytemd-networkd fails to acquire DHCP leases

          # erofs support
          EROFS_FS = yes;
          EROFS_FS_POSIX_ACL = yes;
          EROFS_FS_XATTR = yes;

          # overlayfs support
          OVERLAY_FS = yes;

          # squashfs support
          BLOCK = yes;
          BLK_DEV_LOOP = yes;
          MISC_FILESYSTEMS = yes;
          SQUASHFS = yes;
          SQUASHFS_ZSTD = yes;
          SQUASHFS_CHOICE_DECOMP_BY_MOUNT = yes; # make `mount -o threads=multi` work

          # tmpfs support
          SHMEM = yes; # required for TMPFS
          TMPFS = yes;
          TMPFS_POSIX_ACL = yes;
          TMPFS_XATTR = yes;

          # glibc
          FUTEX = yes; # for pthreads implementation

          # systemd requirements form the manual
          DEVTMPFS = yes;
          CGROUPS = yes;
          INOTIFY_USER = yes;
          SIGNALFD = yes;
          TIMERFD = yes;
          EPOLL = yes;
          UNIX = yes;
          SYSFS = yes;
          PROC_FS = yes;
          FHANDLE = yes;

          # systemd goodies from the manual
          # NET_NS = yes; # option removed in Linux 5.5
          # USER_NS = yes; # option removed in Linux 5.5
          SECCOMP_FILTER = yes;
          NET_SCHED = yes;
          NET_SCH_FQ_CODEL = yes;
          KCMP = yes;
          EVENTFD = yes; # systemd calls it config_event_fd

          # unofficial systemd requirements
          POSIX_TIMERS = yes; # required for systemd-update-utmp
          RSEQ = yes; # used by systemd-update-utmp

          # IO
          PRINTK = yes;
          SERIAL_8250 = yes;
          SERIAL_8250_CONSOLE = yes;
          SERIAL_AMBA_PL011 = if pkgs.hostPlatform.isAarch then yes else unset;
          SERIAL_AMBA_PL011_CONSOLE = if pkgs.hostPlatform.isAarch then yes else unset;
          TTY = yes;

          # make the kernel behave better as a guest
          HYPERVISOR_GUEST = yes;
          KVM_GUEST = yes;
          PARAVIRT = yes;
          # PARAVIRT_SPINLOCKS = yes; # requires `SMP = yes;`
          VIRTIO = yes;
          VIRTIO_CONSOLE = yes;
          X86_X2APIC = if pkgs.hostPlatform.isx86 then yes else unset;

          # virtio networking
          ETHERNET = yes;
          PCI = yes;
          VIRTIO_MENU = yes;
          VIRTIO_NET = yes;
          VIRTIO_PCI = yes;
        };
        ignoreConfigErrors = !pkgs.hostPlatform.isx86;
      }
    );

    nixpkgs.overlays = [
      (final: prev: {
        # https://github.com/NixOS/nixpkgs/issues/154163
        makeModulesClosure = x: prev.makeModulesClosure (x // { allowMissing = true; });

        dbus = prev.dbus.override {
          x11Support = false;
        };

        /*
          The linux kernel depends on util-linux' hexdump, util-linux depends on systemd, hence
          changing systemd implies a rebuild of the linux kernel. For deplyoment, we do not
          recommend keeping this, but it cuts development time quite  a bit to comment this in
        */
        # util-linux = prev.util-linux.override {
        #   systemd = prev.systemd;
        # };

        systemd = prev.systemd.override {
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
          withIptables = false;
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
        };

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

        /*
          A QEMU specifically tailored to execute this initram. It only contains the relevant target
          architectures, and no support for graphical or audio stuff.
        */
        qemu-common = import (prev.path + "/nixos/lib/qemu-common.nix") {
          inherit lib pkgs;
        };
        qemuForThisConfig = prev.buildPackages.qemu.override {
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
          canokeySupport = true;
          capstoneSupport = true;
          pluginsSupport = true;
          hostCpuTargets = [ "${pkgs.stdenv.hostPlatform.qemuArch}-softmmu" ];
        };
      })
    ];
    systemd.coredump.enable = false;

    # avoid any software installed by default
    # TODO filter this via nixos/modules/config/system-path.nix
    # See https://github.com/NixOS/nixpkgs/issues/32405 for further info
    environment.systemPackages = lib.mkForce [
      # essentials
      pkgs.bashInteractive # required, it is the default login shell and in the system closure anyhow
      pkgs.coreutils
      pkgs.systemd

      # goodies already included in the system closure
      pkgs.acl
      pkgs.attr
      pkgs.bzip2
      pkgs.cpio
      pkgs.dbus
      pkgs.dosfstools
      pkgs.findutils
      pkgs.fuse
      pkgs.getent
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gzip
      pkgs.kexec-tools
      pkgs.kmod
      pkgs.libcap
      pkgs.ncurses
      pkgs.nettools
      pkgs.shadow
      pkgs.su
      pkgs.util-linux
      pkgs.xz
      pkgs.zstd

      # debugging aids
      # pkgs.iproute2
      # pkgs.netcat
      # pkgs.socat
      # pkgs.strace
    ];

    # use this to add packages to the early boot stage
    boot.initrd.systemd.initrdBin = [ ];

    # disable nix and nixos-rebuild itself
    nix.enable = false;
    nix.gc.automatic = lib.mkForce false;
    nix.optimise.automatic = lib.mkForce false;
    nixpkgs.hostPlatform = "x86_64-linux";
    system.activatable = true; # Unfortunately required by netboot.nix
    system.switch.enable = false;
    system.switch.enableNg = false;

    # disable services et al that are not strictly necessary
    fonts.fontconfig.enable = false;
    programs.nano.enable = false;
    security.enableWrappers = true; # otherwise login does not work
    security.pam.services.su.forwardXAuth = lib.mkForce false; # avoid su.pam depending on X
    security.sudo.enable = false;
    services.lvm.enable = false;
    services.udev.enable = true; # otherwise mount fails due to missing /dev/disk/by-*
    services.userborn.enable = true; # the alternative is a perl activation script
    system.stateVersion = config.system.nixos.release;
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

    systemd.suppressedSystemUnits = [
      "unit-audit.service"
      "unit-generate-shutdown-ramfs.service"
      "unit-systemd-backlight-.service"
      "unit-systemd-fsck-.service"
      "unit-systemd-importd.service"
      "unit-systemd-mkswap-.service"
    ];

    # setup users
    users.mutableUsers = false;
    # NOTE use `users.users.<name>.hashedPassword` for production use
    users.users.root.initialPassword = "root";

    # enable serial console
    boot.kernelParams = [
      "console=ttyAMA0"
      "console=tty0"
      "console=ttyS0"
    ];

    /*
      The netboot.nix default settings add a dependency on nix itself to register store paths.
      Assuming that nix itself will not be used to modify the system running this initramfs, that
      won't be necessary.
    */
    boot.postBootCommands = lib.mkForce "";

    boot.initrd.systemd.services.initrd-find-nixos-closure = {
      /*
        The original `initrd-find-nixos-closure.service` requires `init=` to be set with the
        absolute path to `${config.system.build.toplevel}/init`. However, its quite inconvenient
        having to set a long absolute nix-store path in the kernel cmdline for the initramdisk to
        work.

        In this service declaration, it is not easily possible to directly refer to
        `${config.system.build.toplevel}/init` without triggering infinite recursion. But, we know
        that there will only be one nixos-closure root in the store, as we intend to never upgade
        a system without regenerating the squashfs. Therefore, we can just glob the path via
        something like `/sysroot/nix/store/*-nixos-system-*`.
      */
      script = lib.mkForce ''
        set -uo pipefail
        export PATH="/bin:${config.boot.initrd.systemd.package.util-linux}/bin:${pkgs.chroot-realpath}/bin"

        closure=(/sysroot/nix/store/*-nixos-system-*/init)
        closure="''${closure#/sysroot}"

        # Resolve symlinks in the init parameter. We need this for some boot loaders
        # (e.g. boot.loader.generationsDir).
        closure="$(chroot-realpath /sysroot "$closure")"

        # Assume the directory containing the init script is the closure.
        closure="$(dirname "$closure")"

        ln --symbolic "$closure" /nixos-closure

        # If we are not booting a NixOS closure (e.g. init=/bin/sh),
        # we don't know what root to prepare so we don't do anything
        if ! [ -x "/sysroot$(readlink "/sysroot$closure/prepare-root" || echo "$closure/prepare-root")" ]; then
          echo "NEW_INIT=''${initParam[1]}" > /etc/switch-root.conf
          echo "$closure does not look like a NixOS installation - not activating"
          exit 0
        fi
        echo 'NEW_INIT=' > /etc/switch-root.conf
      '';
    };

    # only activate what we need filesystem and mass-storage wise
    boot.bcache.enable = false;
    boot.swraid.enable = lib.mkForce false;
    boot.initrd.supportedFilesystems = {
      cifs = lib.mkForce false;
      bcachefs = lib.mkForce false;
      btrfs = lib.mkForce false;
      xfs = lib.mkForce false;
      zfs = lib.mkForce false;
    };
    boot.supportedFilesystems = {
      cifs = lib.mkForce false;
      bcachefs = lib.mkForce false;
      btrfs = lib.mkForce false;
      xfs = lib.mkForce false;
      zfs = lib.mkForce false;
    };

    # a primitive QEMU runner
    system.build.run-with-qemu = pkgs.writeShellApplication {
      name = "run-in-qemu";
      text = ''
        # QEMU leaves the terminal in an unclean state upon exit.
        # See https://github.com/cirosantilli/linux-kernel-module-cheat/issues/110
        trap 'tput smam' EXIT

        ${pkgs.qemu-common.qemuBinary pkgs.qemuForThisConfig} \
          -m size=1G \
          -kernel ${config.system.build.toplevel}/kernel \
          -initrd ${config.system.build.netbootRamdisk}/initrd \
          -append 'console=${pkgs.qemu-common.qemuSerialDevice}' \
          -netdev user,id=n1 -device virtio-net-pci,netdev=n1 \
          -nographic \
          "''${@}"
      '';
    };
  };
}
