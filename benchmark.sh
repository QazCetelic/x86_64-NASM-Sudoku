#!/usr/bin/bash

if [ -n "$1" ]; then
    count="$1"
else
    count=5
fi

if [[ "$PWD" != "/mnt/ramdisk" ]]; then
    echo "Run on RAMDISK"
    exit 1
fi

amount="1000000"
for i in $(seq $count); do
    echo "($i/$count) Started solving ${amount} sudoku's..."
    cat "./${amount}.txt" | /bin/time -f "Solved in %e seconds" sudo nice -19 ./sudoku > ./output
done
