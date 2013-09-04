#!/bin/bash

# This module contains functions used in creating and managing a pre-fork
# worker pool for executing tasks.

# Load utilities module.
source ./utilities.sh

# Load the logging module.
source ./logging.sh

# Load worker library.
source ./worker.sh

Pool () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,taskfile:,queuedir:,pipefile:,logfile:,terminator:,poll:"
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
  local logfile="~/pool.log"
  local terminator="terminate_pool"
  local poll=".1"
  local cmd=""
  local counter="0"

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
  --pipefile:       Named pipe used to issue tasks (default ~/.pool).
  --logfile:        File to keep log data (default ~/pool.log).
  --terminator:     Stop command (default 'terminate_pool').
  --poll:           Idle wait time for worker when queue is empty (default .1).
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
  queuedir="$(_absolute_path "$queuedir")"
  pipefile="$(_absolute_path "$pipefile")"
  logfile="$(_absolute_path "$logfile")"

  DEBUG "$logfile" "Pool called with arguments: workers=$workers taskfile=$taskfile queuedir=$queuedir pipefile=$pipefile logfile=$logfile terminator=$terminator poll=$poll."
  INFO "$logfile" "Attempting to start new pool with $workers workers."

  # Check that taskfile exists.
  if [[ ! -e "$taskfile" ]]; then

    ERROR "$logfile" "Taskfile ($taskfile) not found."
    exit 1

  fi

  # Make sure pipe isn't a regular file.
  if [[ -e "$pipefile" && ! -p "$pipefile" ]]; then

    ERROR "$logfile" "The pipe file ($pipefile) already exists and is not a FIFO."
    exit 1

  fi

  # Create pipe if not already created.
  if [[ ! -e "$pipefile" ]]; then

    mkfifo "$pipefile" 1>&2 2>/dev/null

    if [[ $? != 0 ]];
    then
      ERROR "$logfile" "Could not create named pipe at ($pipefile)."
      exit 1
    fi

  fi

  # Check that the queue dir exists.
  if [[ ! -d "$queuedir" ]]; then

    mkdir -p "$queuedir"

    if [[ $? != 0 ]];
    then
      ERROR "$logfile" "Could not create queue dir ($queuedir)."
      exit 1
    fi

  fi

  for (( i = 0; i < "$workers"; i+=1 )); do

      INFO "$logfile" "Starting worker ($i)."
      Worker \
        --taskfile="$taskfile" \
        --queuefile="$queuedir/$i.tasks" \
        --logfile="$logfile" \
        --terminator="$terminator" \
        --poll="$poll" \
        &

  done

  # Add traps for signals to handle cleanup of workers.
  trap "_stop_workers --workers=$workers --queuedir=$queuedir --logfile=$logfile --terminator=$terminator" SIGINT

  # Listen for messages and dispatch them.
  INFO "$logfile" "Pool entering action loop."
  while read cmd < "$pipefile"
  do

    DEBUG "$logfile" "Pool found new message ($cmd)."

    if [[ "$cmd" == "$terminator" ]]; then

      INFO "$logfile" "Pool received terminator ($terminator). Shutting down."

      _stop_workers \
        --workers="$workers" \
        --queuedir="$queuedir" \
        --logfile="$logfile" \
        --terminator="$terminator"

      break

    fi

    DEBUG "$logfile" "Dispatching ($cmd) to worker ($counter)."
    echo "$cmd" >> "$queuedir/$counter.tasks"
    counter=$(($counter + 1))
    counter=$(($counter % $workers))
  done

}

_stop_workers () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,queuedir:,logfile:,terminator:"
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
  local queuedir="~/.poolq"
  local logfile="~/pool.log"
  local terminator="terminate_pool"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Stop a pool of workers.

Note: This function should not be called directly.

_stop_workers [arguments]

arguments:

  --workers:        Number of workers to stop (default 1).
  --queuedir:       Directory where worker queues are placed (default ~/.poolq).
  --logfile:        File to keep log data (default ~/pool.log).
  --terminator:     Stop command (default 'terminate_pool').
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --workers)
        workers="$2"
        shift 2;;

      --queuedir)
        queuedir="$2"
        shift 2;;

      --logfile)
        logfile="$2"
        shift 2;;

      --terminator)
        terminator="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  taskfile="$(_absolute_path "$taskfile")"
  queuedir="$(_absolute_path "$queuedir")"
  logfile="$(_absolute_path "$logfile")"

  for (( i = 0; i < "$workers"; i++ )); do

    INFO "$logfile" "Pool sending terminator to worker ($i)."
    echo "$terminator" > "$queuedir/$i.tasks"

  done

}
