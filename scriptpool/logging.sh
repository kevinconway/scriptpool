#!/bin/bash

# This module contains methods related to logging.

# Define global variables
SCRIPTPOOL_LOG_LEVEL="${SCRIPTPOOL_LOG_LEVEL-2}"

# Load the utilites module
source ./utilities.sh


ERROR () {

  local logfile="$1"
  local message="$2"

  _log "1" "$logfile" "ERROR: $(date -u): $message"

}


WARN () {

  local logfile="$1"
  local message="$2"

  _log "2" "$logfile" "WARN: $(date -u): $message"

}


INFO () {

  local logfile="$1"
  local message="$2"

  _log "3" "$logfile" "INFO: $(date -u): $message"

}


DEBUG () {

  local logfile="$1"
  local message="$2"

  _log "4" "$logfile" "DEBUG: $(date -u): $message"

}


TRACE () {

  local logfile="$1"
  local message="$2"

  _log "5" "$logfile" "TRACE: $(date -u): $message"

}


_log () {

  local level="$1"
  local logfile="$2"
  local message="$3"

  logfile="$(_absolute_path "$logfile")"

  if (( "$level" <= "$SCRIPTPOOL_LOG_LEVEL" )); then

    touch "$logfile" 1>&2 2>/dev/null
    if [[ $? == 0 ]]; then

      echo "\$\$=$$: \$BASHPID=$BASHPID $message" >> "$logfile"

    fi

    echo "$message" 1>&2

  fi

}
