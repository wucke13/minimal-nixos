# SPDX-FileCopyrightText: 2025-2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  coreutils-full,
  dtc,
}:

writeShellApplication {
  name = "dtb-edit";
  runtimeInputs = [
    dtc
    coreutils-full
  ];

  # TODO what if xdg-open forks to background?
  text = ''
    DTS_FILE="$(mktemp --suffix=.dts)"
    trap cleanup INT TERM

    cleanup(){
      rm -- "$DTS_FILE"
    }

    dtc --in-format dtb --out-format dts --out "$DTS_FILE" -- "$1"
    HASH="$(sha256sum -- "$DTS_FILE")"

    # xdg-open "$DTS_FILE"
    until $EDITOR -- "$DTS_FILE" && dtc --in-format dts --out /dev/null --out-format dtb -- "$DTS_FILE"
    do
      read -N 1 -p "an error was detected, press any key to re-enter the editor" -r
    done


    if [ "$(sha256sum -- "$DTS_FILE")" != "$HASH" ]
    then
      echo "change detected, overwriting $1"
      dtc --in-format dts --out-format dtb --out "$1" -- "$DTS_FILE"
    else
      echo "no change detected, doing nothing"
    fi
  '';
}
