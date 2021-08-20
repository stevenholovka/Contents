#!/bin/bash

# Read the device configuration from the text file in the parent directory
export DEVICECONFIG=$(cat ../DeviceConfiguration.txt)

pushd `dirname $0` > /dev/null
CURDIR=`pwd`
popd > /dev/null

${CURDIR}/build_project.sh --build --config=release
