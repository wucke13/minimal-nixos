# SPDX-FileCopyrightText: 2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{ nixos-init }:

nixos-init.overrideAttrs (old: {
  patches = old.patches ++ [
    ./dev-null-as-default-kernel-fallback.patch
  ];
})
