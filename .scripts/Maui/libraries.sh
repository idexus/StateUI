# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The libraries an application ships, copied into the directory the head
# packages them from. Sourced by build-android.sh and build-linux.sh.
#
# SwiftPM compiles incrementally on its own, and the copy step must not cost
# a full build's worth of work beside that: the Swift runtime is around 100 MB
# and changes only when the TOOLCHAIN does. So a copy keeps its source's
# modification time, and a file is copied when it is missing or its time is
# DIFFERENT - older as much as newer, because another toolchain's runtime
# installed a week ago is older than yesterday's copy of the one before it.
# The names are remembered as they go, and anything else in the directory is
# removed afterwards - a library whose source is gone still disappears, while
# one that has not moved is left where it is.
#
# Bash 3.2 compatible.

WANTED=""

install_so () {
  local source="$1" dest_dir="$2" name
  name="$(basename "$source")"
  WANTED="$WANTED $name"

  if [[ ! -f "$dest_dir/$name" ]] || [[ "$source" -nt "$dest_dir/$name" ]] || [[ "$source" -ot "$dest_dir/$name" ]]; then
    cp -p "$source" "$dest_dir/$name"
  fi
}

remove_the_rest () {
  local dest_dir="$1" so name
  for so in "$dest_dir"/*.so; do
    [[ -f "$so" ]] || continue
    name="$(basename "$so")"
    case " $WANTED " in
      *" $name "*) continue ;;
    esac
    rm -f "$so"
  done
}
