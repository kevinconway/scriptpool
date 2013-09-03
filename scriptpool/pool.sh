#!/bin/bash

# This module contains functions used in creating and managing a pre-fork
# worker pool for executing tasks.

# Load utilities module.
source utilities.sh

# Load worker library.
source workers.sh

Pool () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,taskfile:,queuedir:,pipefile:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "Failure in getopt."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local workers=1
  local taskfile=""
  local queuedir="~/.poolq"
  local pipefile="~/.pool"
  local cmd=""
  local counter="0"
  local poll=".1"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Create a process pool.

Pool [arguments]

arguments:

  --workers:        Number of workers to make (default 1).
  --taskfile:       Library file for workers to source.
  --queuedir:       Directory to place worker queues (default ~/.poolq).
  --pipefile:       Named pipe used to issue tasks (defaul ~/.pool).
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --workers)
        workers="$2"
        shift 2;;

      --taskfile)
        taskfile="$2"
        shift 2;;

      --queuedir)
        queuedir="$2"
        shift 2;;

      --pipefile)
        pipefile="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  taskfile="$(_absolute_path "$taskfile")"
  queuedir="$(_absolute_path "$queuedir")"
  pipefile="$(_absolute_path "$pipefile")"

  # Check that taskfile exists.
  if [[ ! -e "$taskfile" ]]; then

    echo "Taskfile ($taskfile) not found."
    exit 1

  fi

  # Make sure pipe isn't a regular file.
  if [[ -e "$pipefile" && ! -p "$pipefile" ]]; then

    echo "The pipe file ($pipefile) already exists and is not a FIFO."
    exit 1

  fi

  # Create pipe if not already created.
  if [[ ! -e "$pipefile" ]]; then

    mkfifo "$pipefile"

    if [[ $? != 0 ]];
    then
      echo "Could not create named pipe at ($pipefile)."
      exit 1
    fi

  fi

  # Check that the queue dir exists.
  if [[ ! -d "$queuedir" ]]; then

    mkdir -p "$queuedir"

    if [[ $? != 0 ]];
    then
      echo "Could not create queue dir ($queuedir)."
      exit 1
    fi

  fi

  # Spin off workers.
  _start_workers \
    --workers="$workers" \
    --taskfile="$taskfile" \
    --queuedir="$queuedir" \
    --poll="$poll"

  if [[ $? != 0 ]];
  then
    echo "Failed to create workers."
    exit 1
  fi

  # Add traps for signals to handle cleanup of workers.
  trap "_stop_workers --workers=$workers --queuedir=$queuedir" SIGINT

  # Listen for messages and dispatch them.
  while read cmd < "$pipefile"
  do

    if [[ "$cmd" == "terminate_pool" ]]; then

      _stop_workers \
        --workers="$workers" \
        --queuedir="$queuedir"

      break

    fi

    echo "$cmd" >> "$queuedir/$counter.tasks"
    counter=$(($counter + 1))
    counter=$(($counter % $workers))
  done

}
