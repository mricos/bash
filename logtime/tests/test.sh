#!/bin/bash
source ./config.sh
source ../logtime.sh
logtime-clear
logtime-start Unit test 1.
sleep 1
logtime-mark Adding a time marker
logtime-mark Adding a a second time marker
logtime-stop Ending unit test 1.
logtime-commit Commiting unit test 1.
