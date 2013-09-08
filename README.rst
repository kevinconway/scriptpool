==========
ScriptPool
==========

**Worker pools for bash.**

What Is ScriptPool?
===================

ScriptPool is a pre-fork style process pool for bash.

The system is broken down into three interchangeable components:

  - A worker pool that manages multiple worker processes.

  - A worker process that accepts messages from a queue and acts on them.

  - A queue that transports messages from some external process to the worker.

Each of these components has a standardized API which allows them to be mixed
and matched. Current implementations are:

- Pool

  - *Work in progress*

- Worker

  - Echo Worker

    Simply prints all messages to STDOUT.

  - Bash Worker

    Evaluates all messages as bash statements.

  - Proxy Worker

    Delivers messages to a user defined "receive_message" function for custom
    and/or complex functionality.

- Queue

  - Named Pipe Queue

    Uses named pipes as the FIFO source.

  - File Queue

    Uses ordinary text files as the underlying FIFO source.

  - RabbitQueue

    Uses RabbitMQ as the FIFO source.

Show Me
=======

::

    #!/bin/bash

    # Load the desired implementations.
    source /opt/scriptpool/FileQueue.sh
    source /opt/scriptpool/BashWorker.sh

    # Prepare a queue for the worker (normally handled by the pool).
    prepare_queue --identity="MyWorker"

    # Spin off a worker process that listens on that queue.
    Worker --identity="MyWorker" &

    # Put a message on the queue. A unique message id is returned.
    message_id="$(push_message --identity="MyWorker" --message="touch ~/test")"

    echo "Message ID: ($message_id)"

    # Small sleep just to guarantee that the action is done.
    sleep 1

    # A response is recorded once the action is complete. This shows the exit
    # code of the action as well as the output from the action.
    response="$(get_response --messageid="$message_id")"

    echo "Response: ($response)"

    # Signal the worker to spin down.
    push_message --identity="$MyWorker" --message="terminate_worker"

Setup Instructions
==================

ScriptPool is simply a bash function library. Just source the implementations
that you want to use in your script.

Be default, the library expects itself to be installed in /opt.

How Does It Work?
=================

Full scale usage and development documentation in progress. They will be
published via ReadTheDocs.

License
=======

::

    Copyright 2013 Kevin Conway

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


Contributing
============

All contributions to this project are protected under the agreement found in
the `CONTRIBUTING` file. All contributors should read the agreement but, as
a summary::

    You give us the rights to maintain and distribute your code and we promise
    to maintain an open source distribution of anything you contribute.
