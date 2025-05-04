#!/bin/sh

[[ $# -ne 2 ]] && echo "Pls provide two parameters" && exit 1
filesdir=$1
searchstr=$2

[[ ! -d ${filesdir} ]] && echo "${filesdir} is not a directory" && exit 1 

numberFiles=$(find $filesdir -type f | wc -l)

numberMatches=$(grep -r $searchstr $filesdir | wc -l)

echo "The number of files are ${numberFiles} and the number of matching lines are ${numberMatches}"