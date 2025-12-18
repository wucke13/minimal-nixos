# SPDX-FileCopyrightText: 2024-2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  lib,
  ...
}:

{
  imports = lib.lists.filter (x: x != ./. + "/default.nix" && lib.strings.hasSuffix ".nix" x) (
    lib.filesystem.listFilesRecursive ./.
  );
}
