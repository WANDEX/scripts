#!/bin/sh
# take input lines from pipe and for each line execute all provided arguments
# provide -h flag to see examples.

self="$(basename "$0")"
f="${BLD}${ITQ}"

OLDIFS="$IFS"
# set variable to a new line, to use later as a value in Internal Field Separator
NLIFS='
'

USAGE=$(printf "%s" "\
Usage: 'any multiline data' | ${self} [ARGS...]
USAGE ${BLD}EXAMPLES:${END}

${f}# grep all files with pattern and sed -i replace pattern strings:${END}
grep -r '\$BASH_SOURCE' -l | foreach.sh | xargs sed -i 's/\$BASH_SOURCE/\"\$0\"/'

${f}# grep from each *.diff file in current dir:${END}
find . -type f -name *.diff | foreach.sh | xargs grep -i 'Only in'

${f}# sed -i delete lines with pattern strings in all *.diff files at current dir:${END}
find . -type f -name *.diff | foreach.sh | xargs sed -i '/Only in/d'

${f}# sed -i replace pattern strings in all *.diff files at current dir:${END}
find . -type f -name *.diff | foreach.sh | xargs sed -i 's/Only in/SED_REPLACEMENT/g'

${f}# find all files in current dir except *bad* and *out*, sort, concatenate and redirect into file:${END}
find . -type f -name *.diff \( ! -iname "*bad*" ! -iname "*out*" \) | sort -n | foreach.sh | xargs cat > bad.diff
")

case "$1" in
    h|-h|--help|usage)
        echo "$USAGE"
        exit 0
        ;;
esac

# if tty and something is piped into the script
if [ ! -t 0 ]; then
    pipe=$(cat) # /dev/stdin pipe used usually
else
    exit 1 # silently exit.
fi

IFS="$NLIFS"
# do any provided arguments for each line
for line in $pipe; do
    echo "$line" "$@"
done
IFS="$OLDIFS" # restore
