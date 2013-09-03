==========
ScriptPool
==========

**A worker pool for bash.**

What Is ScriptPool?
===================

ScriptPool is a pre-fork style process pool for executing bash functions.

The main process listens on a named pipe for messages. When it receives a
message it dispatches the message to a worker node using a round-robin pattern.
Once a worker node has received the message it will execute the message as a
bash command.

Show Me
=======

::

    #!/bin/bash

    # Load the library.
    source pool.sh

    # Start a pool with eight workers.
    Pool --workers=8 --taskfile="~/my_functions.sh" &

    # Execute a task from the task file (or any bash function) via a worker.
    echo "some_function" > ~/.pool

    # Stop the pool.
    echo "terminate_pool" > ~/.pool

Setup Instructions
==================

ScriptPool is simply bash function library. Just `source` the `pool.sh` file
and make a call to `Pool`.

How Does It Work?
=================

Making a call to the `Pool` function will spin off a series of worker processes
that all listen on their own queue for instructions. The queue files are placed
in the path given by `--queuedir` and are creating in the form
`workerid.tasks` where `workerid` is simply a number between 0 and `--workers`.
Each queue is a normal file and each worker will `source` the library given by
`--taskfile`.

Once all the workers are spun up, the main process (not included in the worker
count) begins listening on the named pipe given by `--pipefile`. As each new
message is received over the pipe the main process distributes it to a worker
queue in a round-robin.

Each worker pops the first line off the queue and executes it as a bash
statement.

Issuing the `terminate_pool` message, or sending SIGINT to the main process,
will wipe all the worker queues and set them to terminate at the next available
cycle.

License
=======

This project is released and distributed under the Apache2 license.

Contributing
============

All contributions to this project are protected under the agreement found in
the `CONTRIBUTING` file. All contributors should read the agreement but, as
a summary::

    You give us the rights to maintain and distribute your code and we promise
    to maintain an open source distribution of anything you contribute.
