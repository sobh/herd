#!/bin/sh
#
# Description:  View packages list stored in CSV file.
#

# If user passed argument, treat it as input file name, else use /dev/stdin
{
	column -t -s "$(printf '\t')"
} < "${1:-/dev/stdin}"
