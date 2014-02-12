#!/bin/bash

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_ID=$(git show-ref --hash HEAD)
BUILD_DATE=$(date +%Y%m%d%H%M%S)
BUILD_BRANCH="build/$BUILD_DATE/$BUILD_ID"

trap on_exit EXIT

function usage () {
cat << EOF
Usage: $0 [OPTIONS]

Build current HEAD, then deploy and run on servers (set for git remote "tz-deploy").
To add or remove server urls, do:
  git remote set-url --add --push tz-deploy <url>
  git remote set-url --delete --push tz-deploy <url>

OPTIONS:
  -p PROCFILE         Use PROCFILE instead of Procfile
  -u URL              Use URL as git remote url
  -f                  Fast deploy, no recompile
EOF
}

function build_sbt () {
  rm --force .gitignore
  sbt clean stage && \
    git add target/scala-2.10/classes/ build.sbt Procfile || exit $?
}

function build_python () {
  echo -e "*.py\ndoc/\ntests/" > .gitignore
  python -m compileall . && \
    git add cda_r2/ custom/ generated/ integration/rabbitmq/ lib/ || exit $?
}

function on_exit () {
  echo "If on build branch; return to source branch, delete build branch."
  local branch=$(git symbolic-ref -q HEAD --short)
  if [[ $branch == build/* ]]; then
    git checkout --force $CURRENT_BRANCH && \
      git branch -D $BUILD_BRANCH
  fi
}

while getopts "hp:u:f" opt; do
  case $opt in
    h)
      usage
      exit 1
      ;;
    p)
      PROCFILE=$OPTARG
      ;;
    u)
      REMOTE_URL=$OPTARG
      ;;
    f)
      FAST_DEPLOY=y
      ;;
  esac
done

echo "Create build $BUILD_BRANCH."

git checkout --orphan $BUILD_BRANCH && \
  git rm --cached -r . || exit $?

if [ -z "$FAST_DEPLOY" ]; then
  echo "Start compile."
  if [ -f "build.sbt" ]; then
    build_sbt
  else
    build_python
  fi
fi

echo "Prepare and commit compiled code."

if [ -n "$PROCFILE" ]; then
  echo "Use alternative Procfile $PROCFILE"
  cp $PROCFILE Procfile || exit $?
fi

if [ -n "$REMOTE_URL" ]; then
  echo "Use git remote url $REMOTE_URL"
  git remote remove tz-deploy && \
    git remote add tz-deploy $REMOTE_URL || exit $?
fi

git add Procfile && \
  git commit -m "Build $BUILD_ID (HEAD commit ref)" || exit $?

echo "Push to deployment server..."
read -p "Press [Enter] to continue"

git push tz-deploy $BUILD_BRANCH || exit $?

