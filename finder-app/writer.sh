#!/bin/bash

[[ $# -ne 2 ]] && echo "2 parameters pls" && exit 1

writefile=$1
writestr=$2

directory=$(dirname ${writefile})

[[ ! -d ${directory} ]] && mkdir -p ${directory}

echo ${writestr} >> ${writefile}