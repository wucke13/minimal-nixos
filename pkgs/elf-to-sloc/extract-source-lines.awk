#!/usr/bin/env -S awk -f
# SPDX-FileCopyrightText: 2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

BEGIN {
  # either space or colon delimit fields
  FS=" |:"
}

# in the `llvm-objdump --line-numbers` ouput sets of assembly instruction with their hex offset
# within the binary are prefixed with the following format:
#
# ; /path/to/source/file:line number
";" == $1 && $3 ~/[0-9]+/ {
  # count how often this line occured
  observed_lines[$2 $3]++;
  # print filename:line number to stdout
  print $2 $3;
}

END{
  # summarize the total number of lines of source code to stderr
  print length(observed_lines) " distinct SLoC" > "/dev/stderr"
}
