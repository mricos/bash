#!/bin/env bash
pdir=/home/mricos/src/mricos/bash
pshell=$pdir/pshell/pshell.sh # full path to this file
ptests=$pdir/pshell/tests.sh # full path to this file
#source $pdir/utils/map-reduce.sh
source $pdir/logtime/logtime.sh
source $pdir/qik/qik.sh
source $pdir/avtool/avtool.sh
function pshell-source() { source $pshell;} #source
function pshell-check() { shellcheck $pshell;} #check
function pshell-edit() { vi $pshell;} #edit with vi
function pshell-dev-next() { echo "write first test";} #next step
function pshell-test() { 
  echo "write first test";
}
