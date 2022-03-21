#!/usr/bin/bash

domain=$1
while read sub; do
  cname=$(host -t CNAME $sub.$domain | grep 'an alias' | awk '{print $NF}'
  
  if [ -z "$cname" ]; then
    continue  # This sends us to the top of the loop instead of running the rest of the block. Square brackets mean "test" and "-z" is checking if it's 0 length
  fi
  
  if ! host $cname &> /dev/null; then
  	echo "$cname did not resolve ($sub.$domain)";
  fi
done