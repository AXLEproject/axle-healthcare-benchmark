#!/bin/bash

if [ $# -ne 1 ];
then
  echo "Usage: $0 <path-to-beans-xml>"
  exit 1
fi

sed -n '/.*BEGIN-DOT.*/,/.*END-DOT.*/{//!p}' $1
