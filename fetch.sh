#!/usr/bin/bash

mkdir -p out  # directory to store output

while read url; do
  filename=$(echo $url | sha256sum | awk '{print $1}')
  filename="out/$filename"
  echo "$filename $url" | tee -a index  # tee takes stdin and splits half to screen and half to file (index) using -a to append
  # Could also use:
  # echo "$filename $url" >> index
  curl -sk -v "$url" &> $filename  # so that we write the output to different files each time
done

# Usage: cat urls | ./fetch.sh