#!/usr/bin/bash

domain=$1
while read sub; do
  if host "$sub.$domain" &> /dev/null; then
  	echo $sub.$domain";
  fi
done

# Usage:
# `./brute.sh example.com < subdomains.txt`
# `cat subdomains.txt | ./brute.sh yahoo.com | awk '{print "https://" $1}' > urls`
# `cat subdomains.txt | ./brute.sh example.com`
