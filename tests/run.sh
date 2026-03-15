#!/bin/bash

for file in *.pl
do
    echo "Running $file"
    swipl -q -s "$file" -g run_tests -t halt
    echo 
    echo 
done