#!/bin/env bash
pdir=/home/mricos/src/mricos/bash
pshell=$pdir/pshell/pshell.sh # full path to this file
ptests=$pdir/pshell/tests.sh # full path to this file
source $pdir/utils/map-reduce.sh
source $pdir/logtime/logtime.sh
source $pdir/qik/qik.sh
function s() { source $pshell;} #source
function c() { shellcheck $pshell;} #check
function v() { vi $pshell;} #edit with vi
function n() { echo "write first test";} #next step
function t() { 
  echo "write first test";
}

