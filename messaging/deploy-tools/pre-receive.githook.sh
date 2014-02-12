#!/bin/bash

# do some basic sanity checks
RUNTIME_DIR=$HOME/runtime
VIRTUAL_ENV=$RUNTIME_DIR/python27/bin/virtualenv

if [ ! -f "$VIRTUAL_ENV" ]; then
  echo Missing virtualenv, aborting.
  exit 1
fi

if [ ! -d "$RUNTIME_DIR/pyenv" ]; then
  echo No pyenv found, creating new environment.
  $VIRTUAL_ENV $RUNTIME_DIR/pyenv
fi

exit $?
