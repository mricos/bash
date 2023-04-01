#!/bin/bash

# sums all tokens passed on the commandline using expr
function sum(){
  local total=0
  for i in "$@"
  do
      total=$(( total + i))
  done
  echo $total
}
    
function resetVars(){
    curFrame=0
    curSample=0
    curline=0
    curEvent=0
    totalVal=0
    numRows=8
    numCols=8
    binSize=256
    numEvents=2048
    numBins=8

    # Cartesian product of 8 binary sets. {0..1} exapands to 2 elements
    dec2bin=( {0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

    expectedColVals=()
    colSqError=()
    rowTotals=()
    colError=()
    colTotals=()
    bins=(0 0 0 0 0 0 0 0)

    # Expected value is N choose k, 
    # 8 summands per sample 
    binsXaxis=(0 0 0 0 0 0 0 0)
    binsEx=(1 7 21 35 35 21 7 1 ) # sum=128, expect 35

    for (( n=0;n<numBins;n++ )); do
        (( binsXaxis[n]=(n+1)*(1<<8)  ))
    done
    #M=()

}

screenToMatrix(){
  M=($(printf "%s\n" "${screen[@]:2:9}" | awk '{print $3 "\n" }'))
  #printf "%s\n" ${M[@]}
}

totalOnesByRow(){
  bits=${1//1/1 }; # substitute 10010 as 1 00 1 0
  sum $bits
}

totalOnesByColInM(){
  numRows="${#M[@]}"
  numCols="${#M[0]}"
  for ((r=0;r<numRows;r++)); do
    row="${M[$r]}"
    for ((c=0;c<numCols;c++)); do
      b=${row:$c:1}
      #echo "$b: before: ${colTotals[@]}"
      ((colTotals[c]=colTotals[c] + b  ))
    done
  done
}

tallyColSumOfRow(){
  row=$1
  for ((c=0;c<numCols;c++)); do
    b=${row:$c:1}
    ((colTotals[c]=colTotals[c] + b  ))
  done
}

binValue(){
  for (( n=0;n<numBins-1;n++ )); do
    if (( "$1" < (( (n+1)*(1<<8))) )); then 
 echo -e "\033[?9h"
       break
    fi
  done
  ((bins[n]=bins[n] + 1 ))
}

sampleSummary(){

  screenToMatrix     # creates $M = 8 lines of 8 bit-chars
  totalOnesByColInM

  colError=()
  for ((c=0;c<numCols;c++)); do
    ((expectedColVals[c] = curSample * numCols/2)) # uniform distribution
  done

  for ((c=0;c<numCols;c++)); do
    ((colError[c] = colTotals[c] - expectedColVals[c] ))
  done

  colSqError=()
  for ((c=0;c<numCols;c++)); do
    ((colSqError[c] =  (colError[c])**2 ))
  done

  colVar=0
  for ((c=0;c<numCols;c++)); do
    ((colVar = (colVar + colSqError[c])  ))
  done
}


makeSummaryText(){
    sampleSummary
    summaryText="$(
    cat <<EOF
    curSample: $curSample curEvent: $curEvent: $val=${dec2bin[$val]}
         expectedVar: sum(colSqErr[@])/8 
              colVar: $colVar
            totalVal: $totalVal
    expectedTotalVal: $(($curSample*$numRows*128))
       totalSqValErr: $((($totalVal-($curSample*$numRows*128))**2))

     expectedColVals: $(printf "%4s " ${expectedColVals[@]})
           colTotals: $(printf "%4s " ${colTotals[@]})
            colError: $(printf "%4s " ${colError[@]})
          colSqError: $(printf "%4s " ${colSqError[@]})
EOF
)"
   echo "$summaryText"
}


compositeLine(){
   screen[$1]="$(combineStrings "${screen[$1]}" "$2")"
}

combineStrings(){
    str1="$1"
    str2="$2"
    len1=${#str1}
    len2=${#str2}

    if (( len1 < len2 )); then
      result="${str1}${str2:len1}"
    else
      result="${str2}${str1:len2}"
   fi

    echo "$result"
}

#######################################################
# Program starts here.
#######################################################

[ -z "$1" ] && resetVars             # state is stored in env vars


((midCol = COLUMNS/2 ))
((midLine = LINES/2 - 6 ))

totalVal=${2:-$totalVal}             # running total passed on command line
numOfFrames=8
timeOld=$time
time=$(date +%s.%N)
deltaTime=$(jq -n "$time-$timeOld")
deltaTime=$(printf "%.3f" $deltaTime)

curline=$curFrame  # frame number
spf=.2 # seconds per frame

# Record event of current sample
#  -vAn         -- supress index
#   -N1         -- 1 byte smallest possible request of /dev/urandom
#   val: 0-255  -- 8 bits as 1 byte unsigned integer
val=$(od -vAn -N1 -td < /dev/urandom \
                      | sed 's/[[:space:]]//g' ) 

((curEvent++))

valOnes="$(totalOnesByRow ${dec2bin[$val]})"
((totalVal = totalVal + $val))
((sampleSum = sampleSum + $val))


headerHeight=3
header="($deltaTime, $spf, $curFrame, $LINES, $COLUMNS)"
screen[0]="$(printf "%${COLUMNS}s\n" "$header")"     # right justify header
screen[1]="$(printf '\n')"                         # blank line
screen[2]="$(printf '\n')"                         # blank line
((curline=headerHeight+curline))	               # lines for header	

totalVal=${2:-0}                                   # total of all events

numOfFrames=8
#curline=$curFrame                                    # frame number

# Record event of current sample
#  -vAn  -> supress index
#   -N1  -> single char smallest possible request of /dev/urandom
#   val: 0-255
val=$(od -vAn -N1 -td < /dev/urandom \
                      | sed 's/[[:space:]]//g' ) 

echo $val >> debug.txt
valOnes="$(totalOnesByRow ${dec2bin[$val]})"         # count 1's in binary
((totalVal = totalVal + $val))                       # sum of all events
((sampleSum = sampleSum + $val))		             # sum of current sample

strToPrint="$(printf "%5s:%2s %5s %10s %5s\n" \
  $curEvent $curFrame $val ${dec2bin["$val"]}  $valOnes)"

compositeLine $((curline++)) "$strToPrint"

for ((i=$curline;i<$midLine;i++)); do               # make space to middle 
  ((curline++))
done

((q1_l =  headerHeight +  7  - curFrame))
lineToAdd="$(printf '%*s' $COLUMNS  "$strToPrint" )"
compositeLine $q1_l "$lineToAdd" 

curline=midLine
screen[ ((curline++)) ]=$(printf "%*s" $(((COLUMNS/2))) + )

mstr="01234567890123456789"
screen[((curline++))]="$(printf "%*s\n" \
                          $((( (${COLUMNS} + ${#mstr})/2  ))) "$mstr" )"
screen[ ((curline++)) ]=$(printf "%*s" $(((COLUMNS/2))) ${#screen[$q1_l]} )

#####################
# Q2 and Q3 go here
#####################
screen[((midLine+2))]="$(printf "%${COLUMNS}s\n" "sampleSum: $sampleSum")"

###################
# FOOTER
###################
footerHeight=5
((curline = LINES -footerHeight ))             # jump to footer

screen[((curline))]="$( printf "%5s"  ${bins[@]})"
screen[((curline++))]+="$( printf "    sum bin event\n")"
screen[((curline))]="$( printf "%5s"  ${binsEx[@]})"
screen[((curline++))]+="$( printf "    expected Bernuoli\n")"
summary="$(makeSummaryText)"

((curline=midLine+8))
while IFS= read -r line; do
  screen[((curline++))]="$line"
done <<< "$summary"



printf "%s\n" "${screen[@]:0:((LINES-1))}"

((curFrame = (curFrame+1) % numOfFrames))

if [[ "$curFrame" == "0" ]];  then
  #read  -t .5 -n1 -s x;
  [[ $x == 'r' ]] && resetVars
  [[ $x == 'q' ]] && return 0
  [[ $x == 'p' ]] && read -s x
    #screen=()                            # clear screen buffer every time
    for ((i=0;i<$LINES;i++)); do
      screen[$i]="$(printf "\n" )"
    done
    sum=0
    curline=0
    sampleSum=0
fi
sleep $spf
source downfall.sh $frame $totalVal
