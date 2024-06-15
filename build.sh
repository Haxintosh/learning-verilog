#!/bin/bash

TOP=""
file=""
debug=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug|-d)
            debug=true
            shift
            ;;
        --file|-f)
            file="$2"
            shift 2
            ;;
        --top|-t)
            TOP="$2"
            shift 2
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$file" || -z "$TOP" ]]; then
    echo "Usage: ./build.sh -f <file> --t <TOP> [-d --debug]
    --debug to generate VCD files"
    exit 1
fi

command="make TOP=\"$TOP\" FILE=\"$file\""

if $debug; 
then
    command+=" test"
else
    command+=" load"
fi

eval "$command" 