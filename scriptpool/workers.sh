#!/bin/bash

# This module contains functions related to managing workers.


_start_workers () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,taskfile:,poll:,queuedir:"
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
  local workers="1"
  local queuedir=""
  local poll=".1"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Start a series of worker nodes.

Note: This method is private and should not be called directly.

_start_workers [arguments]

arguments:

  --workers:        Number of workers to make (default 1).
  --taskfile:       Library file for workers to source.
  --queuedir:       Directory to place worker queues (default ~/.poolq).
  --poll:           Idle time once a queue is empty (default .1).
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

      --poll)
        poll="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Spin off workers.
  for (( i = 0; i < $workers; i+=1 )); do

    echo "Starting worker ($i)"

    rm -f "$queuedir/$i.tasks"
    touch "$queuedir/$i.tasks"

    if [[ $? != 0 ]];
    then
      echo "Error creating task file ($queuedir/$i.tasks)."

      # Kill all workers up to this point.
      _stop_workers \
        --workers="$(($1 + 1))" \
        --queuedir="$queuedir"

      exit 1
    fi

    _start_worker \
      --taskfile="$taskfile" \
      --worker="$i" \
      --queuefile="$queuedir/$i.tasks" \
      --poll="$poll" \
      &

    if [[ $? != 0 ]];
    then
      echo "Error starting worker ($i)."

      # Kill all workers up to this point.
      _stop_workers \
        --workers="$(($1 + 1))" \
        --queuedir="$queuedir"

      exit 1
    fi

  done

}

_start_worker () {

  # Setup for argument parsing.
  local short="h"
  local long="help,worker:,taskfile:,queuefile:,poll:"
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
  local worker="-1"
  local cmd=""
  local poll=".1"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Start a worker process and create its queue.

Note: This method is private and should not be called directly.

_start_worker [arguments]

arguments:

  --worker:         Number associated with this worker.
  --taskfile:       Library file for worker to source.
  --queuefile:      Path to the queue to read from.
  --poll:           Idle time once a queue is empty (default .1).
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --worker)
        worker="$2"
        shift 2;;

      --taskfile)
        taskfile="$2"
        shift 2;;

      --queuefile)
        queuefile="$2"
        shift 2;;

      --poll)
        poll="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  source "$taskfile"

  while true;
  do

    cmd="$(head -n 1 "$queuefile")"

    # Check for stop command from head process.
    if [[ "$cmd" == "terminate_pool" ]]; then

      exit 0

    fi

    # If nothing found in file then wait until the next poll.
    if [[ "$cmd" == "" ]]; then

      sleep "$poll"
      continue

    fi

    # Adjust the file and execute the command.
    tail -n +2 "$queuefile" > "$queuefile.tmp"
    mv "$queuefile.tmp" "$queuefile"

    eval "$cmd"

  done

}


_stop_workers () {

  # Setup for argument parsing.
  local short="h"
  local long="help,workers:,queuedir:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "Failure in getopt."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local workers="-1"
  local queuedir=".1"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Issue the termination command to all workers.

Note: This method is private and should not be called directly.

_stop_workers [arguments]

arguments:

  --workers:         Number of workers that were started.
  --queuedir:        Path to the worker queue directory.
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

      --)
        shift
        break;;
    esac
  done

  for (( i = 0; i < $workers; i+=1 )); do

    _stop_worker \
    --worker="$i" \
    --queuedir="$queuedir"

  done

}


_stop_worker () {

  # Setup for argument parsing.
  local short="h"
  local long="help,worker:,queuedir:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "Failure in getopt."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local worker="-1"
  local queuedir=""

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"

Issue the termination command to a worker.

Note: This method is private and should not be called directly.

_stop_worker [arguments]

arguments:

  --worker:         Number associated with this worker.
  --queuedir:       Path to the worker queue directory.
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --worker)
        worker="$2"
        shift 2;;

      --queuedir)
        queuedir="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  echo "terminate_pool" > "$queuedir/$worker.tasks"

}
