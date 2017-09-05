#!/bin/bash

basedir="`dirname "$0"`"

cd "$basedir" &&
    LL_default=2 ./bin/add-on.sh add "$@"
