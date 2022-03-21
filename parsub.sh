#!/usr/bin/bash

domain=$1
while read sub; do
  echo $sub.$domain
done | xargs -n1 -P10 ./sub.sh

# Alternatively something like:
# xargs -P10 -n1 -I{} ./sub.sh "{}.$domain"

# Usage:
# cat subdomains.txt | ./parsub.sh yahoo.com