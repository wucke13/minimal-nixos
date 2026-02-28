# SPDX-FileCopyrightText: 2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  gawk,
  llvmPackages,
}:

writeShellApplication {
  name = "elf-to-sloc";
  runtimeInputs = [
    gawk
    llvmPackages.llvm
  ];
  text = ''
    llvm-objdump --line-numbers "$1" | awk -f ${./extract-source-lines.awk}
  '';
}
