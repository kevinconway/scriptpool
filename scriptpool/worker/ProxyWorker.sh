#!/bin/bash

# This module contains an implementation of the worker interface that simply
# evaluates all messages as bash statement.

# This module assumes that you have sourced an implementation of the queue
# interface.

# This module assumes that you have defined, or sourced a file that defines,
# a function called receive_message that will handle acting on messages.

# This is the directory where the common libraries are stored.
SCRIPTPOOL_COMMON_DIR="${SCRIPTPOOL_COMMON_DIR:-"/opt/scriptpool/common"}"

# Load the utilities module
source "$SCRIPTPOOL_COMMON_DIR/utilities.sh"

# Load the logging module
source "$SCRIPTPOOL_COMMON_DIR/logging.sh"


Worker () {

  # Setup for argument parsing.
  local short="h"
  local long="help,identity:,poll:,terminator:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    ERROR "The getopt call failed in the Worker function."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local terminator="terminate_worker"
  local poll=".1"
  local message=""
  local messageid=""
  local response=""

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Create a worker process.

Worker [arguments]

arguments:

--identity:       A unique value used to identify the worker (required).
--poll:           Idle time once a queue is empty (default .1 seconds).
--terminator:     Message to stop the worker (default terminate_worker).
BLOCK

        echo "$help_message"
        exit 1
        shift;;

      --identity)

        identity="$2"
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

  if [[ "$(echo "$identity" | sed s/\ //g)" == "" ]]; then

    ERROR "Identity cannot be empty."
    exit 1

  fi

  while true;
  do

    # Grab a new message off the queue.
    message="$(pop_message --identity="$identity")"

    # Split the message and the message id
    messageid="$(echo "$message" | awk '{ print $1 }')"
    message="$(echo $message | sed s/"$messageid *"//)"

    # Deal with empty messages (empty queues) if found.
    if [[ "$(echo "$message" | sed s/" *"//g)" == "" ]]; then

      sleep "$poll"
      continue

    fi

    # Deal with terminator if found.
    if [[ "$message" == "$terminator" ]]; then

      set_response --messageid="$messageid" --status=0 --response="$message"
      exit 0

    fi

    response="$(receive_message "$message" 2>&1)"

    set_response --messageid="$messageid" --status=$? --response="$response"

  done

}
