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

  - Named Pipe Pool

    This pool listens on a named pipe for messages to dispatch.

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
    source /opt/scriptpool/queue/FileQueue.sh
    source /opt/scriptpool/worker/BashWorker.sh
    source /opt/scriptpool/pool/NamedPipePool.sh

    # Spin up a pool of 8 worker processes.
    Pool --workers=8 &

    # Wait a second to make sure the pool is spun up.
    sleep 1

    # Have one of the workers create the ~/hello file.
    echo "touch ~/hello" > ~/.scriptpool/poolpipe

    # Wait a half second to make sure the file is created.
    sleep .5

    # Have one of the workers put content into the ~/hello file.
    echo "echo 'HELLO' > ~/hello" > ~/.scriptpool/poolpipe

    # Wait a half second to make sure the content is written.
    sleep .5

    # Have all workers shut down. This includes the pool process.
    echo "terminate_pool" > ~/.scriptpool/poolpipe

    # See the results.
    cat ~/hello

Obviously this is a trivial example. More complex behaviour such as long
running tasks, task chaining, and custom message handling are possible with
the ProxyWorker.

How Does It Work?
=================

Full scale usage and development documentation in progress. They will be
published via ReadTheDocs.

Setup Instructions
==================

ScriptPool is simply a bash function library. Just source the implementations
that you want to use in your script.

Be default, the library expects itself to be installed in /opt.

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
