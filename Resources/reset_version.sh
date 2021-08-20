#!/bin/bash

pushd `dirname $0` > /dev/null
CURDIR=`pwd`
popd > /dev/null

${CURDIR}/build_project.sh --reset-version
