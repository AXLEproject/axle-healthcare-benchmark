#!/bin/bash
#
# Copyright (c) 2013, Portavita BV Netherlands
#
source $HOME/.bashrc

PROJECT_DIR=$(cd "${BASH_SOURCE[0]%/*}" && pwd -P)

cd $PROJECT_DIR
exec mvn scala:run -DmainClass=eu.portavita.axle.Generator $@
