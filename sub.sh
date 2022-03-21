#!/bin/bash

domain=$1

if host $domain &> /dev/null; then
  echo $domain
fi

# Usage:
# cat	subdomains.txt | awk '{print $1 ".sbtuk.net"}' | xargs -n1 -P10 ./subs.sh