#!/bin/bash

PATH="$PATH:bin"
basedir="`dirname "$0"`"

cd "$basedir" &&
    LL_default=2 start-vnc.sh viewer "$@"
