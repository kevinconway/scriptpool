#!/bin/bash

# This module contains an implementation of the queue interface that uses a
# named pipe as the underlying data store.

# This is the directory used by the queue implementation to store data.
# By default it is a hidden directory in the current user's home.
SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE="${SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE:-"~/.scriptpool"}"

# This is the directory where the common libraries are stored.
SCRIPTPOOL_COMMON_DIR="${SCRIPTPOOL_COMMON_DIR:-"/opt/scriptpool/common"}"

# Load the utilities module
source "$SCRIPTPOOL_COMMON_DIR/utilities.sh"

# Load the logging module
source "$SCRIPTPOOL_COMMON_DIR/logging.sh"


prepare_queue () {

  # Setup for argument parsing.
  local short="h"
  local long="help,identity:,recreate"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    ERROR "The getopt call failed in the prepare_queue function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local recreate="false"
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Create a worker queue.

prepare_queue [arguments]

arguments:

  --identity:       Identity of the worker listenting to this queue (required).
  --recreate:       Flag to destroy an existing queue if found (optional).
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --identity)

        identity="$2"
        shift 2;;

      --recreate)

        recreate="true"
        shift;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$identity" | sed s/\ //g)" == "" ]]; then

    ERROR "Identity cannot be empty."
    return 1

  fi

  _create_queue_dirs
  if [[ $? != 0 ]]; then

    ERROR "Could not create queue workspace ($workspace)."
    return 1

  fi

  # Destroy queue file if recreate flag is set.
  if [[ "$recreate" == "true" ]]; then

    destroy_queue --identity="$identity"
    if [[ $? != 0 ]]; then

      ERROR "Could not destroy queue ($identity)."
      return 1

    fi

  fi

  # Create the queue file.
  mkfifo "$workspace/queues/$identity" 1>&2 2>/dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not create queue file ($workspace/queues/$identity)."
    return 1

  fi

}


_create_queue_dirs () {

  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  # Ensure that the queue base directory is created.
  if [[ ! -d "$workspace" ]]; then

    mkdir -p "$workspace" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue base directory ($workspace)."
      return 1

    fi

  fi

  # Ensure that the queue storage directory is created.
  if [[ ! -d "$workspace/queues" ]]; then

    mkdir -p "$workspace/queues" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue storage directory ($workspace/queues)."
      return 1

    fi

  fi

  # Ensure that the queue results directory is created.
  if [[ ! -d "$workspace/results" ]]; then

    mkdir -p "$workspace/results" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue results directory ($workspace/results)."
      return 1

    fi

  fi

}


destroy_queue () {

  # Setup for argument parsing.
  local short="h"
  local long="help,identity:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    ERROR "The getopt call failed in the destroy_queue function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Destroy a worker queue.

destroy_queue [arguments]

arguments:

  --identity:       Identity of the worker listenting to this queue (required).
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --identity)

        identity="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$identity" | sed s/\ //g)" == "" ]]; then

    ERROR "Identity cannot be empty."
    return 1

  fi

  if [[ -e "$workspace/queues/$identity" ]]; then

    rm -rf "$workspace/queues/$identity" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not destroy queue file ($workspace/queues/$identity)."
      return 1

    fi

  fi

}

push_message () {

  # Setup for argument parsing.
  local short="h"
  local long="help,identity:,message:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    ERROR "The getopt call failed in the push_message function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local message=""
  local message_identity="$(cat /proc/sys/kernel/random/uuid)"

  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Put a message in the worker queue.

push_message [arguments]

arguments:

  --identity:       Identity of the worker listenting to this queue (required).
  --message:        The message to place on the queue (required).

output:

  This function prints the unique message identity on STDOUT.
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --identity)

        identity="$2"
        shift 2;;

      --message)

        message="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$identity" | sed s/\ //g)" == "" ]]; then

    ERROR "Identity cannot be empty."
    return 1

  fi

  # Validate Input
  if [[ "$(echo "$message" | sed s/\ //g)" == "" ]]; then

    ERROR "Message cannot be empty."
    return 1

  fi

  # This command blocks until a consumer calls pop_message on the same queue.
  echo "$message_identity $message" >> "$workspace/queues/$identity"
  if [[ $? != 0 ]]; then

    ERROR "Could not write message ($message) to queue ($workspace/queues/$identity)."
    return 1

  fi

  echo "$message_identity"

}

pop_message () {

  # Setup for argument parsing.
  local short="h"
  local long="help,identity:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "The getopt call failed in the pop_message function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local message=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Pop the first message off the worker queue.

pop_message [arguments]

arguments:

  --identity:       Identity of the worker listenting to this queue (required).

output:

  This function prints the message on STDOUT in this form:

    <MESSAGE_ID> <MESSAGE>
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --identity)

        identity="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$identity" | sed s/\ //g)" == "" ]]; then

    echo "Identity cannot be empty."
    return 1

  fi

  # This command blocks until push_message is called on the same queue.
  message="$(head -n 1 "$workspace/queues/$identity")"
  if [[ $? != 0 ]]; then

    ERROR "Could not read from queue ($workspace/queues/$identity)."
    return 1

  fi

  echo "$message"

}

set_response () {

  # Setup for argument parsing.
  local short="h"
  local long="help,messageid:,status:,response:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "The getopt call failed in the set_response function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local status="0"
  local response=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Record the status of a message.

set_response [arguments]

arguments:

  --messageid:      The unique id of the message (required).
  --status:         The status code for the response (default 0).
  --response:       The value of the response to set (default empty string).
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --messageid)

        messageid="$2"
        shift 2;;

      --status)

        status="$2"
        shift 2;;

      --response)

        response="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$messageid" | sed s/\ //g)" == "" ]]; then

    echo "Message id cannot be empty."
    return 1

  fi

  touch "$workspace/results/$messageid" 1>&2 2>/dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not create results file ($workspace/results/$messageid)."
    return 1

  fi

  echo "$status $response" > "$workspace/results/$messageid"
  if [[ $? != 0 ]]; then

    ERROR "Could not write result ($status $response) to ($workspace/results/$messageid)."
    return 1

  fi

}

get_response () {

  # Setup for argument parsing.
  local short="h"
  local long="help,messageid:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "The getopt call failed in the get_response function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local response=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_WORKSPACE")"

  while true;
  do
    case "$1" in

      -h|--help)

        local help_message=""

        read -d '' help_message <<"BLOCK"
Get the status of a message.

set_response [arguments]

arguments:

  --messageid:      The unique id of the message (required).
BLOCK

        echo "$help_message"
        return 1
        shift;;

      --messageid)

        messageid="$2"
        shift 2;;

      --)
        shift
        break;;
    esac
  done

  # Validate Input
  if [[ "$(echo "$messageid" | sed s/\ //g)" == "" ]]; then

    echo "Message id cannot be empty."
    return 1

  fi

  if [[ ! -e "$workspace/results/$messageid" ]]; then

    echo ""
    return 0

  fi

  response="$(cat "$workspace/results/$messageid")"
  if [[ $? != 0 ]]; then

    ERROR "Could not read from results file ($workspace/results/$messageid)."
    return 1

  fi

  echo "$response"

}
