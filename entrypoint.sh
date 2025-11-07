#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Start the Docker daemon service
start-docker.sh

# Execute the specified command (CMD or command passed on run)
# Using 'exec' ensures that signals (like SIGTERM for graceful shutdown)
# are passed directly to the application (i.e., "$@") and not the shell script.
exec "$@"