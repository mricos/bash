#!/bin/bash
TERM=xterm
PS1="slides>"
echo LINES are $LINES
echo COLUNMS are $COLUMNS
echo $(tty) > ./viewer-tty
