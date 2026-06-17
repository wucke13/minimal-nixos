# SPDX-FileCopyrightText: 2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

/*
  Pinout:
  - https://wiki.friendlyelec.com/wiki/images/c/c4/NEO_pinout-02.jpg
  - https://wiki.friendlyelec.com/wiki/images/e/e3/NanoPi-NEO-AIR_pinout-02.jpg
*/
{
  lib,
  pkgsCross,
  pkgsBuildBuild,
  stdenv,
  coreutils-full,
  dosfstools,
  genimage,
  mtools,
  ubootTools,
  board ? "orangepi-pc",
  bootVariant ? "fel",
  ...
}@args:

assert lib.assertOneOf "board" board [
  "bananapi-m2-plus"
  "beelink-x2"
  "libretech-all-h3-cc"
  "nanopi-duo2"
  "nanopi-m1"
  "nanopi-m1-plus"
  "nanopi-neo"
  "nanopi-neo-air"
  "orangepi-2"
  "orangepi-lite"
  "orangepi-one"
  "orangepi-pc"
  "orangepi-pc-plus"
  "orangepi-plus"
  "orangepi-plus2e"
  "orangepi-zero-plus2"
  "zeropi"
];

assert lib.assertOneOf "bootVariant" bootVariant [
  "fel" # -> boot fel via USB
];

let
  pkgs = pkgsCross.armv7l-hf-multiplatform;

  ubootDefconfigs = {
    bananapi-m2-plus = "bananapi_m2_plus_h3_defconfig";
    beelink-x2 = "beelink_x2_defconfig";
    libretech-all-h3-cc = "libretech_all_h3_cc_h3_defconfig";
    nanopi-duo2 = "nanopi_duo2_defconfig";
    nanopi-m1 = "nanopi_m1_defconfig";
    nanopi-m1-plus = "nanopi_m1_plus_defconfig";
    nanopi-neo = "nanopi_neo_defconfig";
    nanopi-neo-air = "nanopi_neo_air_defconfig";
    orangepi-2 = "orangepi_2_defconfig";
    orangepi-lite = "orangepi_lite_defconfig";
    orangepi-one = "orangepi_one_defconfig";
    orangepi-pc = "orangepi_pc_defconfig";
    orangepi-pc-plus = "orangepi_pc_plus_defconfig";
    orangepi-plus = "orangepi_plus_defconfig";
    orangepi-plus2e = "orangepi_plus2e_defconfig";
    orangepi-zero-plus2 = "orangepi_zero_plus2_h3_defconfig";
    zeropi = "zeropi_defconfig";
  };

  linuxDtbs = {
    "bananapi-m2-plus-v1.2" = "sun8i-h3-bananapi-m2-plus-v1.2.dtb";
    bananapi-m2-plus = "sun8i-h3-bananapi-m2-plus.dtb";
    beelink-x2 = "sun8i-h3-beelink-x2.dtb";
    emlid-neutis-n5h3-devboard = "sun8i-h3-emlid-neutis-n5h3-devboard.dtb";
    libretech-all-h3-cc = "sun8i-h3-libretech-all-h3-cc.dtb";
    mapleboard-mp130 = "sun8i-h3-mapleboard-mp130.dtb";
    nanopi-duo2 = "sun8i-h3-nanopi-duo2.dtb";
    nanopi-m1 = "sun8i-h3-nanopi-m1.dtb";
    nanopi-m1-plus = "sun8i-h3-nanopi-m1-plus.dtb";
    nanopi-neo = "sun8i-h3-nanopi-neo.dtb";
    nanopi-neo-air = "sun8i-h3-nanopi-neo-air.dtb";
    nanopi-r1 = "sun8i-h3-nanopi-r1.dtb";
    orangepi-2 = "sun8i-h3-orangepi-2.dtb";
    orangepi-lite = "sun8i-h3-orangepi-lite.dtb";
    orangepi-one = "sun8i-h3-orangepi-one.dtb";
    orangepi-pc = "sun8i-h3-orangepi-pc.dtb";
    orangepi-pc-plus = "sun8i-h3-orangepi-pc-plus.dtb";
    orangepi-plus = "sun8i-h3-orangepi-plus.dtb";
    orangepi-plus2e = "sun8i-h3-orangepi-plus2e.dtb";
    orangepi-zero-plus2 = "sun8i-h3-orangepi-zero-plus2.dtb";
    rervision-dvk = "sun8i-h3-rervision-dvk.dtb";
    zeropi = "sun8i-h3-zeropi.dtb";
  };

  /*
    For more information, check out
    https://linux-sunxi.org/U-Boot#Compile_U-Boot
    and
    https://linux-sunxi.org/FriendlyARM_NanoPi_NEO_%26_AIR
  */
  uboot = pkgs.buildUBoot {
    defconfig = lib.attrsets.getAttr board ubootDefconfigs;
    extraMeta.platforms = [ "armv7l-linux" ];
    filesToInstall = [
      "u-boot" # ELF file, for debugging
      "u-boot-env.txt" # default environment dump
      "u-boot-sunxi-with-spl.bin" # U-Boot with SPL bootable via FEL
    ];
    postBuild = ''
      ./scripts/get_default_envs.sh > u-boot-env.txt
    '';
    passthru = {
      felBoot = felBootGenerator { };
    };
  };

  felBootGenerator =
    {
      kernelFile ? null,
      dtbFile ? null,
      ramdiskFile ? null,
    }@args:
    let
      inherit (lib.strings) optionalString;
      inherit (lib.lists) count;
      inherit (builtins) any hasAttr toString;

      knownArguments = [
        "kernelFile"
        "dtbFile"
        "ramdiskFile"
      ];

      anyKnownArgumentsPresent = (any (attr: hasAttr attr args) knownArguments);

      countOfKnownArguments = count (attr: hasAttr attr args) knownArguments;
    in
    pkgsBuildBuild.writeShellApplication {
      name = "boot-${board}-via-fel";
      runtimeInputs = with pkgsBuildBuild; [
        sunxi-tools
        ubootTools
      ];

      text = ''
        # collect arguments for sunxi-fel
        SUNXI_FEL_ARGS=(
          uboot ${uboot}/u-boot-sunxi-with-spl.bin
        )
      ''
      + optionalString anyKnownArgumentsPresent ''

        # read u-boot-env into bash array
        declare -A UBOOT_ENV
        while IFS='=' read -d $'\n' -r key value
        do
          UBOOT_ENV[$key]="$value"
        done < "${uboot}/u-boot-env.txt"

        # collect artefacts and memory addresses to be uploaded
        SUNXI_FEL_ARGS+=('multiwrite' ${toString countOfKnownArguments})
      ''
      + optionalString (args ? kernelFile) ''
        SUNXI_FEL_ARGS+=("''${UBOOT_ENV[kernel_addr_r]}" ${kernelFile})
      ''
      + optionalString (args ? dtbFile) ''
        SUNXI_FEL_ARGS+=("''${UBOOT_ENV[fdt_addr_r]}" ${dtbFile})
      ''
      + optionalString (args ? ramdiskFile) ''
        cleanup(){
          if [ -f "$UBOOT_RAMDISK_IMAGE" ]
          then
            echo "removing $UBOOT_RAMDISK_IMAGE"
            rm -- "$UBOOT_RAMDISK_IMAGE"
          fi
        }
        trap cleanup EXIT

        UBOOT_RAMDISK_IMAGE=$(mktemp --suffix uInitrd)
        mkimage -A ${pkgs.stdenv.hostPlatform.linuxArch} -T ramdisk -C none -n uInitrd -d ${args.ramdiskFile} "$UBOOT_RAMDISK_IMAGE"
        SUNXI_FEL_ARGS+=("''${UBOOT_ENV[ramdisk_addr_r]}" "$UBOOT_RAMDISK_IMAGE")
      ''
      + ''

        set -x

        # get version of board
        sunxi-fel version

        # boot uboot
        sunxi-fel --verbose --progress  "''${SUNXI_FEL_ARGS[@]}"

        { set +x; } 2>/dev/null
      '';

      # To boot these, run the following in Uboot:
      # bootz $kernel_addr_r $ramdisk_addr_r $fdt_addr_r
    };

  qemuLauncher = pkgsBuildBuild.writeShellApplication {
    name = "run-${disk-image.name}-qemu";
    runtimeInputs = with pkgsBuildBuild; [ qemu ];
    text = ''
      # run this on shutdown to clean up state modified by this tool
      cleanup(){
        if [ -z "$SD_DESTINATION" ]
        then
          echo "removing $SD_DEFINITION"
          rm -- "$SD_DESTINATION"
        fi
      }
      trap cleanup EXIT

      # define variable
      SD_DESTINATION=$(mktemp --suffix=.img)

      # grow SD card to power of 2
      cp -- ${disk-image}/disk.img "$SD_DESTINATION"
      # TODO find smallest bigger power of two, via log2
      qemu-img resize -f raw "$SD_DESTINATION" 512M

      # launch qemu
      qemu-system-arm \
        -machine orangepi-pc \
        -drive file="$SD_DESTINATION",format=raw \
        -nographic \
        "''${@}"
    '';
  };

  disk-image = stdenv.mkDerivation {
    name = "allwinner-h3-${board}";
    dontUnpack = true;

    nativeBuildInputs = [
      coreutils-full
      dosfstools # make fat filesystems
      genimage # create disk images
      mtools # modify FAT filesystems without mounting
      ubootTools # create uboot-images and -scripts
    ];

    /*
      For info on required SD-Card partition layout, consult
      https://linux-sunxi.org/Bootable_SD_card
    */
    installPhase = ''
      runHook preInstall

      mkdir -- "$out"

      # Populate the files intended for the boot partition
      mkdir --parent -- input/boot/dtbs
      pushd input/boot

      ${lib.strings.optionalString (args ? kernel) "cp -- ${args.kernel}/zImage ./"}
      ${lib.strings.optionalString (args ? kernel) "cp -- ${args.kernel}/dtbs/sun8i-h3-*.dtb ./dtbs"}
      ${lib.strings.optionalString (args ? initrd) ''
        mkimage -A ${pkgs.stdenv.hostPlatform.linuxArch} -T ramdisk -C none -n uInitrd -d ${args.initrd}/initrd ./uInitrd
      ''}
      mkimage -T script -d ${./boot.txt} boot.scr.uimg

      popd

      # collect disk image artifacts
      ln --symbolic -- ${uboot}/*.bin input/

      # generate the disk image
      genimage --outputpath "$out" --config ${./genimage.cfg}

      runHook postInstall
    '';
    /*
      Notes:
      - setting partition 1 as bootable makes uboot pick the bootscript from that partition
    */
    passthru = {
      inherit
        qemuLauncher
        uboot
        ;
      felBoot = felBootGenerator {
        kernelFile = "${args.kernel}/zImage";
        ramdiskFile = "${args.initrd}/initrd";
        dtbFile = "${args.kernel}/dtbs/${lib.attrsets.getAttr board linuxDtbs}";
      };

      tftp-root = disk-image.overrideAttrs (old: {
        postInstall = ''
          rm --recursive --force -- "$out"
          mv -- input/boot "$out"
        '';
      });
    }
    // lib.attrsets.getAttrs [ "kernel" "initrd" ] args;
  };
in
disk-image
