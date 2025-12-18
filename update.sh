#!/usr/bin/env bash
# 
# SPDX-FileCopyrightText: 2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ZORNIX_HOME="$(fd --glob --max-results 1 --type directory zornix ~)"

cp --recursive --verbose -- \
  "$ZORNIX_HOME"{{lib,overlay,treefmt}.nix,.github} \
  ./

cp --recursive --verbose -- \
  "$ZORNIX_HOME"vanilla-nixos-configurations/minimal*.nix \
  ./nixos-configurations/

cp --recursive --verbose -- \
  "$ZORNIX_HOME"nixos-modules/embedded \
  ./nixos-modules/

cp --recursive --verbose -- \
  "$ZORNIX_HOME"pkgs/{check-commits.nix,minimal-linux-kernel.nix,update-ci} \
  ./pkgs/
