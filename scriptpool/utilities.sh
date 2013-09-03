#!/bin/bash

# This module contains misc. helper functions.

_absolute_path () {

  local path="$1"

  # Expand special characters like '~'.
  eval path="$path"

  # Get absolute paths of items by following symlinks.
  path="$(readlink -m "$path")"

  echo "$path"

}
