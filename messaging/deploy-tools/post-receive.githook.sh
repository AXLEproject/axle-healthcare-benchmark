#!/bin/bash
set -x

APP_DIR=$HOME/apps/tz-instance
LOG_DIR=$HOME/log
PROCFILE=$APP_DIR/Procfile
RUNNER=$HOME/bin/shoreman.sh
NODE_NAME=$(uname --nodename)

read OLDHASH NEWHASH REFNAME

echo "Started deployment on $NODE_NAME."

function setup_env () {
  cd $APP_DIR
  if [ -d $HOME/runtime/pyenv ]; then
    source $HOME/runtime/pyenv/bin/activate || exit $?
  fi
  if [ -f "build.sbt" ]; then
    sbt stage || exit $?
  fi
}

function run_instance () {
  local cmd=${RUNNER##*/}
  local pids=$(ps -C $cmd -o pid=)
  if [ ${#pids} -ne 0 ]; then
    echo "Sending TERM and wait to stop running instances ($pids)."
    killall --signal SIGTERM --wait $cmd
  fi

  mkdir --parents $APP_DIR
  GIT_WORK_TREE=$APP_DIR git checkout --force $REFNAME || exit $?

  echo "Setting up environment."
  setup_env

  echo "Run new instance."
  ( exec setsid $RUNNER $PROCFILE > $LOG_DIR/tz-instance.log 2>&1 & ) &
}

run_instance

echo "Finished deployment on $NODE_NAME."
