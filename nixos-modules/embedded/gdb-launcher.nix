# SPDX-FileCopyrightText: 2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.zorn.boot.kernelDebugging;

  # helper functions for conditional kernel config options
  mkIf = x: if x then lib.kernel.yes else lib.kernel.unset;
  hpl = pkgs.stdenv.hostPlatform;
in
{
  options.zorn.boot.kernelDebugging = {
    enable = lib.options.mkEnableOption "debug config options";
    enableKernelDebugConfigOptions = lib.options.mkEnableOption "debug config options";
    enableGdbLauncher = lib.options.mkEnableOption "gdb launcher script" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {

    /*
      Wrapper arround GDB which launches with kernel source code and the lx-* linux helper commands
      readily available in GDB.

      Recommendations:

      - add `-append 'nokaslr'` to the QEMU call, kernel address randomization
        confuses gdb regarding debug symbols
      - use hardware breakpoints, via `hbreak`
      - breakpoint on `start_kernel` chew through the boring bootstrapping assembly
      - to debug init, use `run_init_process` or `kernel_execve` as breakpoint
      - use `apropos lx` to get an overview over functions and commands from these scripts
    */
    system.build.gdbLauncher = pkgs.buildPackages.writeShellApplication {
      name = "run-${config.system.name}-gdb";
      text =
        let
          kernelSrc = pkgs.srcOnly config.system.build.kernel;

          kernelBuiltWithGdb = kernelSrc.overrideAttrs (old: {

            phases = [
              "unpackPhase"
              "patchPhase"
              "configurePhase"
              "installPhase"
            ];

            /*
              `make scripts_gdb` --- make sure the gdb scripts are built as well. "Building" them is
              necessary, as this step implies the generation of a file with constants like addresses
              etc. that the scripts rely upon to navigate the kerenl memory layout at run-time.

              `symlinks -cr .` --- replaces all absolute symlinks with relative ones. This is
              necessary, as during build all the stuff resides in `/build/*`, but later it gets
              copied to `/nix/store/*`, thus invalidating all the absolute symlinks.
            */
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.symlinks ];
            postConfigure = ''
              pushd build
              make scripts_gdb
              symlinks -cr .
              ln --symbolic --relative --force -- ../scripts/gdb/vmlinux-gdb.py ./
              popd
            '';

            installPhase = ''
              cd ..
              cp -pr --reflink=auto -- . $out
            '';
          });

          gdbRcInit = pkgs.writeTextFile {
            name = "linux-kernel-gdbrc";
            text = ''
              add-auto-load-safe-path ${kernelBuiltWithGdb}
              directory ${kernelBuiltWithGdb}/build
              source ${kernelBuiltWithGdb}/build/vmlinux-gdb.py
              target remote :1234
            '';
          };
        in
        ''
          gdb --command=${gdbRcInit} \
            --eval-command='tui layout regs' \
            --eval-command='focus cmd' \
            --eval-command='hbreak start_kernel' \
            --tui \
            --cd=${kernelBuiltWithGdb}/build \
            ${config.system.build.kernel.dev}/vmlinux \
            "''${@}"
        '';
    };

    # make kernel more friendly to debugging
    boot.kernelPatches = lib.mkIf cfg.enableKernelDebugConfigOptions (
      lib.singleton {
        name = "enable-kernel-debugging";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          DEBUG_INFO = yes; # make sure debug info is in vmlinux
          DEBUG_INFO_DWARF5 = yes; # make sure that the more efficient DWARF5 format is used
          GDB_SCRIPTS = yes; # emit the gdb launcher scripts from the kernel
          UNWINDER_ARM = mkIf hpl.isArmv7;
        };
      }
    );
  };
}
