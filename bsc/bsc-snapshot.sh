#!/bin/bash

if [ $# -eq 1 ]; then
    dir=$(pwd)
elif [ $# -eq 2 ]; then
    dir=$2
else
    echo "Usage: $0 <uri> [filepath] "
    exit 1
fi

uri=$1
filename=$(basename "$uri")
status=-1

while (( status != 0 )); do
    PIDS=$(pgrep aria2c)
    
    if [ -z "$PIDS" ]; then
        aria2c -d $dir -o $filename -s14 -x14 -k1024M $uri
    fi

    status=$?
    pid=$(pidof aria2c)
    wait $pid

    echo "aria2c exit."

    case $status in
        3)
            echo "File not exist."
            exit 3
            ;;
        9)
            echo "No space left on device."
            exit 9
            ;;
        *)
            continue
            ;;
    esac
done

# Extract files without storing in an archive
cd $dir
echo "Extracting files..."
tar -xvf "$filename"

# Remove the archive file
rm "$filename"

echo "Download and extraction succeed."
exit 0