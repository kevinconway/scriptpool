#!/bin/bash

# This module contains methods related to logging.

# This variable controls which levels of messages get logged to the log file.
SCRIPTPOOL_LOG_LEVEL="${SCRIPTPOOL_LOG_LEVEL:-2}"

# This variable, when true, will set the module to print logs on STDERR.
SCRIPTPOOL_LOG_VERBOSE="${SCRIPTPOOL_LOG_VERBOSE:-false}"

# This variable sets the log file location.
# The default is a file in the user's home.
SCRIPTPOOL_LOG_FILE="${SCRIPTPOOL_LOG_FILE:-"~/pool.log"}"

# This is the directory where the common libraries are stored.
SCRIPTPOOL_COMMON_DIR="${SCRIPTPOOL_COMMON_DIR:-"/opt/scriptpool/common"}"

# Load the utilities module.
source "$SCRIPTPOOL_COMMON_DIR/utilities.sh"


ERROR () {

  local message="$1"

  _log "1" "ERROR: $(date -u): $message"

}


WARN () {

  local message="$1"

  _log "2" "WARN: $(date -u): $message"

}


INFO () {

  local message="$1"

  _log "3" "INFO: $(date -u): $message"

}


DEBUG () {

  local message="$1"

  _log "4" "DEBUG: $(date -u): $message"

}


TRACE () {

  local message="$1"

  _log "5" "TRACE: $(date -u): $message"

}


_log () {

  local level="$1"
  local message="$2"
  local logfile="$(get_absolute_path "$SCRIPTPOOL_LOG_FILE")"

  if (( "$level" <= "$SCRIPTPOOL_LOG_LEVEL" )); then

    # Lazy create the logfile when needed.
    # Output piped to /dev/null to prevent screen clutter.
    touch "$logfile" 1>&2 2>/dev/null
    if [[ $? == 0 ]]; then

      # Each log line comes with releveant pids and message.
      echo "\$\$=$$: \$BASHPID=$BASHPID: $message" >> "$logfile"

    fi

    if [[ "$SCRIPTPOOL_LOG_VERBOSE" == "true" ]]; then

      echo "$message" 1>&2

    fi

  fi

}
