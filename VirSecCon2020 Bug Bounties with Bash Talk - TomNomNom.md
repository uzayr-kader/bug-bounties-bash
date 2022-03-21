# Bug Bounties with Bash, @TomNomNom
Talk: https://www.youtube.com/watch?v=s9w0KutMorE
Slides: https://tomnomnom.com/talks/bug-bounties-with-bash-virsec.pdf
Files in order of use/creation in talk:
0. subdomains.txt
1. brute.sh
2. cnames.sh
3. fetch.sh
4. sub.sh
5. parsub.sh

## Bash
Bash is a shell
A shell wraps the kernel so you can launch processes

### Other shells
* `zsh`
* `fish`
* `ksh`
* `explorer.exe`

## Core utils
* `grep` - search for patterns in files or stdin
* `sed` - edit the input stream
* `awk` - general purpose text-processing language
* `cat` - concatenate files
* `find` - list files recursively and apply filters
* `sort` - sort the lines from stdin
* `uniq` - remove duplicate lines from stdin
* `xargs` - run a command using each line from stdin as an argument
* `tee` - copy stdin to a file and to the screen

## IO Streams
Linux has 3 standard streams:
* `stdin` (file descriptor 0) - default=keyboard
* `stdout` (file descriptor 1) - default=screen
* `stderr` (file descriptor 2) - default=screen

### Redirect standard streams
* `< file` connects a file to stdin
* `> file` redirects stdout to a file
* `2> file` redirects stderr to a file
* `&> file` redirects stdout and stderr to a file
* `2>&1` redirects stderr to stdout!

## Subshell Tricks
* `<(cmd)` - returns the output of `cmd` as a file descriptor
  - Handy if you want to diff the output of 2 commands
  - e.g. `diff <(cmd-one) <(cmd-two)`
* `$(cmd)` - returns the output text of `cmd`
  - Handy if you want to store the command output in a variable
  - e.g. `myvar=$(cmd)`

## Enumerating Subdomains
### External services
  - hackertarget.com
  - crt.sh
  - certspotter.com
### Brute force
You will need:
  - A target
  - A wordlist
  - Bash :)

### Check if target resolves
`host example.com` returns an IPv4 and IPv6 address
`host non-existent.com` returns not found
#### Exit codes
Exit codes can be used to smartly catch this information
`$?` holds the exit code of the last run command
| Value of `$?` | Meaning |
|-----|-----|
| 0 | Success |
| 1 | Operation not permitted |
| 2 | No such file or directory |
| 3 | No such process |

#### Conditionals
```
fi this-command-works;
then
  run-this-command
fi
```
For the example of resolving hosts:
`if host example.com; then echo "IT RESOLVES \o/"; fi
`if host non-existent.com; then echo "IT RESOLVES \o/"; fi
But these still output their full response before echoing

**Tidying up:**
`&> /dev/null` redirects `stdout` and `stderr` to `/dev/null` which can be considered a black hole that you can throw data into.

So the commands become:
`if host example.com &> /dev/null; then echo "IT RESOLVES \o/"; fi
`if host non-existent.com &> /dev/null; then echo "IT RESOLVES \o/"; fi
And the output is only what we want to see

#### Loops
```
while this-command-works do;
  this-command
done
```
##### Looping over `stdin`
`while read sub; do echo "$sub.sbtuk.net"; done < subdomains.txt`
Which attaches the contents of `subdomains.txt` to the `stdin`

#### Putting It Together
`while read sub; do if host "$sub.example.com" &> /dev/null; then echo $sub.example.com"; fi; done < subdomains.txt`
Which is looking really messy

## Shell scripts
Create a `brute.sh` file and use `chmod u+x ./brute.sh`
```
#!/usr/bin/bash  # Hit !! in command mode in Vim, then which bash and Enter to auto input this location /usr/bin/bash

while read sub; do
  if host "$sub.example.com" &> /dev/null; then
  	echo $sub.example.com";
  fi
done < subdomains.txt
```
### Make it generic
This way you can provide the domain on the terminal:
```
#!/usr/bin/bash  # Hit !! in command mode in Vim, then which bash and Enter to auto input this location /usr/bin/bash

domain=$1
while read sub; do
  if host "$sub.$domain" &> /dev/null; then
  	echo $sub.$domain";
  fi
done < subdomains.txt
```

e.g. `$ ./brute.sh example.com`

To make it even more versatile, remove subdomains.txt
```
#!/usr/bin/bash

domain=$1
while read sub; do
  if host "$sub.$domain" &> /dev/null; then
  	echo $sub.$domain";
  fi
done
```
Now `$ ./brute.sh example.com` will hang (using the keyboard input is now the `stdin` as the keyboard is the default
Or more usefully can run:
* `./brute.sh example.com < subdomains.txt`
* `cat subdomains.txt | ./brute.sh example.com`

## Dangling CNAMEs
The Plan:
* Check subdomains for CNAME records
* Check if those CNAMEs resolve
* If they don't, it's possible to buy those and technically have control over the original name
`host example.com` not found
`host -t CNAME example.com` shows that it's an alias for something else `lol-whoop.com`
`host lol-whoops.com` not found - this is a problem

### Getting the CNAMEs
`host -t CNAME invalid.sbtuk.net` returns a domain:
`invalid.sbtuk.net is an alias for lolifyouregisteredthisyouwastedyourmoney.com.`
To capture that domain:
`host -t CNAME invalid.sbtuk.net | grep 'an alias' | awk '{print $NF}'`
`$NF` stands for number of fields (separated by spaces), so in this case same as $6 and it's the last field of the output line.

Now working with `cnames.sh` starting in the same place as `brute.sh`
```
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
```

## Fetching Targets
* Having lots of targets to look at can be overwhelming
`curl https://example.com -o example.txt` can be used to grab the HTML of a webpage
`cat subdomains.txt | ./brute.sh target.com | awk '{print "https://" $1}'` > urls.txt
Open up a new file `fetch.sh`
```
#!/usr/bin/bash

mkdir -p out  # directory to store output

while read url; do
  filename=$(echo $url | sha256sum | awk '{print $1}')
  filename="out/$filename"
  echo "$filename $url" | tee -a index  # tee takes stdin and splits half to screen and half to file (index) using -a to append
  # Could also use:
  # echo "$filename $url" >> index
  curl -sk "$url" -o $filename &> /dev/null  # so that we write the output to different files each time
done
```
`curl -sk` runs the silent flag and flag to ignore certificate errors

### Using Grep
Now that we have the HTML fetched, we need to sift through it.
Some things to grep for:
* Titles
* Server headers
* Known ‘subdomain takeover’ strings - repo on GitHub with a list of these
* URLs (and then go and fetch the URLs by feeding back into `fetch.sh`!)
  - JavaScript files
* Secrets
* Error messages
* File upload forms
* Interesting Base64 encoded strings
  - (eyJ|YTo|Tzo|PD[89])

E.g. `grep -oiE "<title>(.*)</title>" *` using flags for (-o)nly the parts that match, case (-i)nsensitivity and (-E)xtended regex grep

To fetch Headers we can modify the curl command to use (-v)erbose
`curl -sk -v "$url" &> $filename`

Looking at the file can see that lines for the headers start with `<` character so grep for it. Using `-h` to exclude filename from response and `sort -u` to get unique list of headers
`grep -hE '^< ' * | sort -u`

## Speeding Things Up
* Pipes give you some parallelisation for free
  - It’s not enough though
* xargs can run things in parallel…
* Let’s speed up our subdomain brute-forcer

### Messy method
```
#!/bin/bash

domain=$1
xargs -P1 -n1 -I{} bash -c "
  if host \"{}.$domain\" &> /dev/null; then
    echo \"{}.$domain\"
  fi
"
```
Create a new shell script `sub.sh`
```
#!/bin/bash

domain=$1
if host $domain &> /dev/null; then
  echo $domain
fi
```
Now we can run:
`cat	subdomains.txt | awk '{print $1 ".sbtuk.net"}' | xargs -n1 -P10 ./subs.sh`
which takes the various subdomain.domain lines as input and uses `xargs` to run 10 processes in parallel (1 line each)

Now creating: `parsub.sh`
```
#!/usr/bin/bash

domain=$1
while read sub; do
  echo $sub.$domain
done | xargs -n1 -P10 ./sub.sh
```
Allowing us to run:
`cat subdomains.txt | ./parsub.sh yahoo.com`

## Bits And Bobs
* Use dtach for long-running tasks
  - `dtach -c sess bash` allows you to run something, hit Ctrl+\ to detach and carry on with other things. Use `dtach -a sess` in another shell to see what it's doing and use `exit` to terminate the `dtach`
* vim is a major part of my workflow
* When things get complex, consider a different language…
  - Go, Python, etc.
  - Check out meg, comb, unfurl, waybackurls, gf, httprobe, concurl...