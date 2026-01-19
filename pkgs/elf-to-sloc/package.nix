# SPDX-FileCopyrightText: 2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  coreutils-full,
  gawk,
  llvmPackages,
}:

writeShellApplication {
  name = "elf-to-sloc";
  runtimeInputs = [
    coreutils-full
    gawk
    llvmPackages.llvm
  ];
  text = ''
    llvm-objdump --line-numbers "$1" | awk -f ${./extract-source-lines.awk}
  '';
}
