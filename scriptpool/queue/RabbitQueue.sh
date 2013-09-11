#!/bin/bash

# This module contains an implementation of the queue interface that uses a
# RabbitMQ server as the datastore.

# These variables control how the queue implementation communicates with
# RabbitMQ.
SCRIPTPOOL_RABBITQUEUE_USER="${SCRIPTPOOL_RABBITQUEUE_USER:-"guest"}"
SCRIPTPOOL_RABBITQUEUE_PWD="${SCRIPTPOOL_RABBITQUEUE_PWD:-"guest"}"
SCRIPTPOOL_RABBITQUEUE_HOST="${SCRIPTPOOL_RABBITQUEUE_HOST:-"localhost"}"
SCRIPTPOOL_RABBITQUEUE_PORT="${SCRIPTPOOL_RABBITQUEUE_PORT:-"5672"}"

SCRIPTPOOL_RABBITQUEUE_WORKSPACE="${SCRIPTPOOL_RABBITQUEUE_WORKSPACE:-~/.scriptpool}"

# This implementation relies on the management plugin for rabbit having been
# enabled.

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
  local rabbit_client="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"
  rabbit_client="$rabbit_client/rabbitmqadmin"

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

  _create_workspace
  if [[ $? != 0 ]]; then

    ERROR "Could not create workspace ($SCRIPTPOOL_RABBITQUEUE_WORKSPACE)."
    return 1

  fi

  _download_rabbit_admin
  if [[ $? != 0 ]]; then

    ERROR "Could not download rabbit admin client."
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
  "$rabbit_client" declare queue name="$identity" > /dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not create queue for identity ($identity)."
    return 1
  fi

}


_create_workspace () {

  local workspace="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"

  # Ensure that the workspace directory is created.
  if [[ ! -d "$workspace" ]]; then

    mkdir -p "$workspace" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create workspace at ($workspace)."
      return 1

    fi

  fi

  # Ensure that the results directory is created.
  if [[ ! -d "$workspace/results" ]]; then

    mkdir -p "$workspace/results" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create results dir at ($workspace/results)."
      return 1

    fi

  fi

}


_download_rabbit_admin () {

  local workspace="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"

  # Ensure that the workspace directory is created.
  if [[ ! -d "$workspace" ]]; then

    mkdir -p "$workspace" 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could not create workspace at ($workspace)."
      return 1

    fi

  fi

  if [[ ! -e "$workspace/rabbitmqadmin" ]]; then

    pushd "$workspace" > /dev/null

    wget http://localhost:15672/cli/rabbitmqadmin 1>&2 2>/dev/null
    if [[ $? != 0 ]]; then

      ERROR "Could wget rabbit client (http://localhost:15672/cli/rabbitmqadmin)."
      return 1

    fi

    chmod +x ./rabbitmqadmin
    if [[ $? != 0 ]]; then

      ERROR "Could not set execution bit for rabbit client ($workspace/rabbitmqadmin)."
      return 1

    fi

    popd > /dev/null

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
  local rabbit_client="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"
  rabbit_client="$rabbit_client/rabbitmqadmin"

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

  "$rabbit_client" delete queue name="$identity" > /dev/null
  if [[ $? != 0 ]]; then

      ERROR "Could not destroy queue with client ($identity)."
      return 1

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

  local rabbit_client="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"
  rabbit_client="$rabbit_client/rabbitmqadmin"

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

  if [[ "$(echo "$message" | sed s/\ //g)" == "" ]]; then

    ERROR "Message cannot be empty."
    return 1

  fi

  "$rabbit_client" publish routing_key="$identity" payload="$message_identity $message" > /dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not publish message ($message) on queue ($identity)."
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
    ERROR "The getopt call failed in the pop_message function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local identity=""
  local message=""
  local rabbit_client="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"
  rabbit_client="$rabbit_client/rabbitmqadmin"

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

    ERROR "Identity cannot be empty."
    return 1

  fi

  # Unfortunately, there is no easy way to get only the message payload from
  # the rabbit client. Instead, it offers various human readable formats for
  # printing out the query results. Here the "kvp", or key-value pair, format
  # has been chosen which prints all data in the form of "key=value". This
  # regex based rewrite does make assumptions about the message content. This
  # means that if the order of the printout ever changes, this regex will also
  # need to change.
  # TODO(kevinconway): Look into parsing the mysql style table for data.
  message="$("$rabbit_client" --format=kvp get queue="$identity" requeue=false)"
  if [[ $? != 0 ]]; then

    ERROR "Could not retrieve message for queue ($identity)."
    return 1

  fi

  message="$(echo "$message" | sed s/".*payload=\"\(.*\)\" payload_bytes.*"/\\1/g)"
  if [[ $? != 0 ]]; then

    ERROR "Could not parse message from queue ($identity)."
    return 1

  fi

  # The rabbit client returns "No items" when the queue is empty.
  # The "No items" message is not affected by the sed rewrite.
  if [[ "$message" == "No items" ]]; then

    echo ""
    return 0

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
    ERROR "The getopt call failed in the set_response function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local status="0"
  local response=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"

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

    ERROR "Message id cannot be empty."
    return 1

  fi

  touch "$workspace/results/$messageid" 1>&2 2>/dev/null
  if [[ $? != 0 ]]; then

    ERROR "Could not create results file ($workspace/results/$messageid)"
    return 1

  fi

  echo "$status $response" > "$workspace/results/$messageid"
  if [[ $? != 0 ]]; then

    ERROR "Could not write ($status $response) to ($workspace/results/$messageid)."
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
    ERROR "The getopt call failed in the get_response function."
    return 1
  fi

  # Set vars in scope.
  eval set -- "$args"

  # Set local vars.
  local messageid=""
  local response=""
  local workspace="$(get_absolute_path "$SCRIPTPOOL_RABBITQUEUE_WORKSPACE")"

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

    ERROR "Message id cannot be empty."
    return 1

  fi

  if [[ ! -e "$workspace/results/$messageid" ]]; then

    echo ""
    return 0

  fi

  response="$(cat "$workspace/results/$messageid")"
  if [[ $? != 0 ]]; then

    ERROR "Could not read results file ($workspace/results/$messageid)."
    return 1

  fi

  echo "$response"

}
