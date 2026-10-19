#!/bin/bash
set -e

# Initialize Lmod for commands as well as interactive shells.
source /etc/profile.d/lmod.sh

exec "$@"
