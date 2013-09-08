#!/bin/bash

# This module contains an implementation of the queue interface that uses a
# named pipe as the underlying data store.

# This is the directory used by the queue implementation to store data.
# By default it is a hidden directory in the current user's home.
SCRIPTPOOL_NAMEDPIPEQUEUE_DIR="${SCRIPTPOOL_NAMEDPIPEQUEUE_DIR:-"~/.scriptpool"}"

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
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local recreate="false"
  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  _create_queue_dirs

  # Destroy queue file if recreate flag is set.
  if [[ "$recreate" == "true" ]]; then

    destroy_queue --identity="$identity"

  fi

  # Create the queue file.
  mkfifo "$q_dir/queues/$identity" 1>&2 2>/dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not create queue file ($q_dir/queues/$identity)."
    exit 1
  fi

}


_create_queue_dirs () {

  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

  # Ensure that the queue base directory is created.
  if [[ ! -d "$q_dir" ]]; then

    mkdir -p "$q_dir" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue base directory ($q_dir)."
      exit 1

    fi

  fi

  # Ensure that the queue storage directory is created.
  if [[ ! -d "$q_dir/queues" ]]; then

    mkdir -p "$q_dir/queues" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue storage directory ($q_dir/queues)."
      exit 1

    fi

  fi

  # Ensure that the queue results directory is created.
  if [[ ! -d "$q_dir/results" ]]; then

    mkdir -p "$q_dir/results" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create queue results directory ($q_dir/results)."
      exit 1

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
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  if [[ -e "$q_dir/queues/$identity" ]]; then

    rm -rf "$q_dir/queues/$identity" 1>&2 2>/dev/null

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
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local message=""
  local message_identity="$(cat /proc/sys/kernel/random/uuid)"

  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  # Validate Input
  if [[ "$(echo "$message" | sed s/\ //g)" == "" ]]; then

    ERROR "Message cannot be empty."
    exit 1

  fi

  # The FD 7 has no significance. This function simply needed an FD in RW mode
  # to allow nonblocking writes to the named pipe.

  echo "$message_identity $message" >> "$q_dir/queues/$identity" &

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
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local message=""
  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  message="$(head -n 1 "$q_dir/queues/$identity")"

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
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local status="0"
  local response=""
  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  touch "$q_dir/results/$messageid" 1>&2 2>/dev/null

  echo "$status $response" > "$q_dir/results/$messageid"

}

get_response () {

  # Setup for argument parsing.
  local short="h"
  local long="help,messageid:"
  local args=$(getopt -o "$short" --long "$long"  -- "$@")
  if [[ $? != 0 ]];
  then
    echo "The getopt call failed in the get_response function."
    exit 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local response=""
  local q_dir="$(get_absolute_path "$SCRIPTPOOL_NAMEDPIPEQUEUE_DIR")"

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
        exit 1
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
    exit 1

  fi

  if [[ ! -e "$workspace/results/$messageid" ]]; then

    echo ""
    return 0

  fi

  response="$(cat "$q_dir/results/$messageid")"

  echo "$response"

}
