#!/usr/bin/env bash
set -euo pipefail

rc_in=queze_no_lua.rc
out=queze.rc

lua=$(for f in $(ls -v src/*.lua); do cat "$f"; echo; done)

{
  cat "$rc_in"
  printf '<\n%s\n>\n' "$lua"
} > "$out"
