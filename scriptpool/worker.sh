#!/bin/bash

# This module contains the worker process.

# Load the utilities module.
source ./utilities.sh

# Load the logging module.
source ./logging.sh


Worker () {

  # Setup for argument parsing.
  local short="h"
  local long="help,taskfile:,queuefile:,poll:,terminator:,logfile:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "Failure in getopt."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local taskfile=""
  local queuefile=""
  local poll=".1"
  local terminator="terminate_worker"
  local logfile="~/worker.log"
  local cmd=""
  local response=""

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Start a worker process and create its queue.

Worker [arguments]

arguments:

  --taskfile:       Library file for worker to source.
  --queuefile:      Path to the queue to read from (created if not found).
  --logfile:        Path to log file (default /var/log/scriptpool/worker.log).
  --poll:           Idle time once a queue is empty (default .1).
  --terminator:     Message to stop the worker (default 'terminate_worker').
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --taskfile)
        taskfile="$2"
        shift 2;;

      --queuefile)
        queuefile="$2"
        shift 2;;

      --logfile)
        logfile="$2"
        shift 2;;

      --terminator)
        terminator="$2"
        shift 2;;

      --poll)
        poll="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  taskfile="$(_absolute_path "$taskfile")"
  queuefile="$(_absolute_path "$queuefile")"
  logfile="$(_absolute_path "$logfile")"

  DEBUG "$logfile" "Worker called with arguments: taskfile=$taskfile queuefile=$queuefile poll=$poll terminator=$terminator logfile=$logfile."
  INFO "$logfile" "Attempting to start a new worker."

  # Ensure that the taskfile exists and source it.
  if [[ ! -e "$taskfile" ]]; then

    ERROR "$logfile" "Taskfile ($taskfile) not found."
    exit 1

  fi
  source "$taskfile"

  # Remove any existing queue file that exists and recreate it.
  if [[ -e "$queuefile" ]]; then

    rm -f "$queuefile"

    if [[ $? != 0 ]]; then

      ERROR "$logfile" "Failed to edit queue at ($queuefile)"
      exit 1

    fi

  fi

  touch "$queuefile" 1>&2 2>/dev/null
  if [[ $? != 0 ]]; then

    ERROR "$logfile" "Failed to create queue at ($queuefile)."
    exit 1

  fi

  INFO "$logfile" "Worker entering action loop."
  while true;
  do

    cmd="$(head -n 1 "$queuefile")"

    # Check for stop command from head process.
    if [[ "$cmd" == "$terminator" ]]; then

      INFO "$logfile" "Worker received terminator ($terminator). Shutting down."
      exit 0

    fi

    # If nothing found in file then wait until the next poll.
    if [[ "$cmd" == "" ]]; then

      TRACE "$logfile" "No messages in queue. Sleeping for ($poll) seconds."
      sleep "$poll"
      continue

    fi

    DEBUG "$logfile" "Worker found new message ($cmd)."

    # Adjust the file and execute the command.
    TRACE "$logfile" "Adjusting queue ($queuefile) up one."
    tail -n +2 "$queuefile" > "$queuefile.tmp"
    mv "$queuefile.tmp" "$queuefile"

    response="$(eval "$cmd" 2>&1)"
    if [[ $? != 0 ]]; then
      WARN "$logfile" "Execution of ($cmd) failed with message ($response)."
    fi

  done

}
