#!/bin/bash
source ./logtime.sh
export TIMELOG="./test.txt"
export LT_STATE_DIR="./state"
export LT_DATA_DIR="./data"
logtime-clear
logtime-start Unit test 1.
sleep 1
logtime-mark Adding a time marker
logtime-mark Adding a a second time marker
logtime-status
logtime-stop Ending unit test 1.
logtime-commit Commiting unit test 1.
