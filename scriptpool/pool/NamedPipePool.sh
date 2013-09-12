#!/bin/bash

# This module contains an implementation of the pool interface that uses a
# named pipe as the underlying communication platform.

# This is the directory used by the pool implementation to store data.
# By default it is a hidden directory in the current user's home.
SCRIPTPOOL_NAMEDPIPEPOOL_WORKSPACE="${SCRIPTPOOL_NAMEDPIPEPOOL_WORKSPACE:-"~/.scriptpool"}"

# This is the directory where the common libraries are stored.
SCRIPTPOOL_COMMON_DIR="${SCRIPTPOOL_COMMON_DIR:-"/opt/scriptpool/common"}"

# Load the utilities module
source "$SCRIPTPOOL_COMMON_DIR/utilities.sh"

# Load the logging module
source "$SCRIPTPOOL_COMMON_DIR/logging.sh"


Pool () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,terminator:,poll:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    ERROR "The getopt call failed in the Pool function."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local workers="1"
  local terminator="terminate_pool"
  local poll=".1"
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEPOOL_WORKSPACE")"
  local counter="0"
  local worker_id=""
  local worker_pid="0"
  local message=""
  local next_worker=""
  local message_id=""

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Create a worker pool.

Pool [arguments]

arguments:

  --workers:          Number of workers to make (default 1).
  --terminator:       Stop command (default 'terminate_pool').
  --poll:             Idle time for a worker when queue is empty (default .1).
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --workers)

        workers="$2"
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


  _prepare_workspace

  # Create workers.
  for ((counter=0; $counter<$workers; counter+=1))
  do

    worker_id="$(cat /proc/sys/kernel/random/uuid)"

    prepare_queue --identity="$worker_id" --recreate
    if [[ $? != 0 ]]; then

      ERROR "Could not prepare queue for ($worker_id)."
      _stop_workers
      exit 1

    fi

    Worker --identity="$worker_id" --poll="$poll" --terminator="$terminator" &

    worker_pid="$!"

    echo "$worker_pid $worker_id" >> "$workspace/workers"

  done

  # Listen for messages.
  while true
  do

    message="$(head -n 1 "$workspace/poolpipe")"

    # Handle the terminator message if found.
    if [[ "$message" == "$terminator" ]]; then

      _stop_workers "$terminator"
      exit 0

    fi

    # Deal with empty messages if found.
    if [[ "$(echo "$message" | sed s/" *"//g)" == "" ]]; then

      sleep "$poll"
      continue

    fi

    # Grab the next worker in line.
    next_worker="$(_get_next_worker)"
    if [[ $? != 0 ]]; then

      ERROR "Could not fetch next worker for ($message)."
      _stop_workers
      exit 1

    fi

    # Split the PID and identity.
    worker_pid="$(echo "$next_worker" | awk '{ print $1 }')"
    worker_id="$(echo "$next_worker" | awk '{ print $2 }')"

    # Dispatch message to the worker.
    message_id="$(push_message --identity="$worker_id" --message="$message")"
    if [[ $? != 0 ]]; then

      ERROR "Could not dispatch message ($message) to ($worker_id)."
      _stop_workers
      exit 1

    fi

  done

}


_prepare_workspace () {

  # Check that workspace is created.
  if [[ ! -d "$workspace" ]]; then

    mkdir -p "$workspace"
    if [[ $? != 0 ]]; then

      ERROR "Could not create pool workspace ($workspace)."
      exit 1

    fi

  fi

  # Check that the worker file is created.
  if [[ ! -e "$workspace/workers" ]]; then

    touch "$workspace/workers" > /dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create worker file ($workspace/workers)."
      exit 1

    fi

  fi

  # Clear the worker file.
  echo -n "" > "$workspace/workers"
  if [[ $? != 0 ]]; then

    ERROR "Could not write to worker file ($workspace/workers)."
    exit 1

  fi

  # Check that the pipe exists.
  if [[ ! -e "$workspace/poolpipe" ]]; then

    mkfifo "$workspace/poolpipe" > /dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create pipe ($workspace/poolpipe)."
      exit 1

    fi

  fi

}


_get_next_worker () {

  local worker=""

  worker="$(head -n 1 "$workspace/workers")"

  tail -n +2 "$workspace/workers" > "$workspace/workers.tmp"

  mv "$workspace/workers.tmp" "$workspace/workers"

  echo "$worker" >> "$workspace/workers"

  echo "$worker"

}


_stop_workers () {

  local terminator="$1"
  local line=""
  local worker_pid=""
  local worker_id=""
  local message_id=""

  while read line
  do

    worker_pid="$(echo "$line" | awk '{ print $1 }')"
    worker_id="$(echo "$line" | awk '{ print $2 }')"

    message_id="$(push_message --identity="$worker_id" --message="$terminator")"

  done < "$workspace/workers"

}
