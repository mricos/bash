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
    frame=0
    curSample=1
    scurline=0
    curEvent=0
    totalVal=0
    numRows=8
    numCols=8
    binSize=256
    numEvents=2048
    numBins=8
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

    M=()
    screen=()  # build text as array of strings in screen
}

[ -z "$1" ] && resetVars

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
  for (( n=0;n<numBins;n++ )); do
    if (( "$1" < (( (n+1)*(1<<8))) )); then 
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
  (( colVar/=numCols))
}



#######################################################
# Program starts here.
#######################################################
clear
totalVal=${2:-$totalVal}
spf=.1 # seconds per frame
numOfFrames=8
time=$(date +%s%N)
curline=$frame  # frame number

# Record event of current sample
#-vAn -> supress index
# -N1  -> single char smallest possible request of /dev/urandom
val=$(od -vAn -N1 -td < /dev/urandom \
                      | sed 's/[[:space:]]//g' ) 

((curEvent++))

valOnes="$(totalOnesByRow ${dec2bin[$val]})"
((totalVal = totalVal + $val))
((sampleSum = sampleSum + $val))

header="($time, $spf, $frame, $LINES, $COLUMNS)"
((w= COLUMNS-${#header[@]}))

screen[0]="$(printf "%${w}s\n" "$header")"
screen[1]="$(printf '\n')"
((screenline=2+curline))

screen[$screenline]="$(printf "%5s %5s %s %s\n" \
  $curline $val ${dec2bin[$val]} $valOnes)"
((curline+=1))

n=$(( LINES/2 )) 

start=$((screenline+1))
for ((i=$start;i<$n;i++)); do
  screen[$i]="$(printf "\n" )"
done

if [[ "$frame" == "7" ]];  then
  sampleSummary
  binValue $sampleSum
summaryText=$(cat <<EOF
curSample: $curSample curEvent: $curEvent: $val=${dec2bin[$val]}
 expectedColVals: $(printf "%4s " ${expectedColVals[@]})
       colTotals: $(printf "%4s " ${colTotals[@]})
        colError: $(printf "%4s " ${colError[@]})
      colSqError: $(printf "%4s " ${colSqError[@]})
     expectedVar: sum(colSqErr[@])/8 
          colVar: $colVar
        totalVal: $totalVal
expectedTotalVal: $(($curSample*$numRows*128))
   totalSqValErr: $((($totalVal-($curSample*$numRows*128))**2))

r-reset, p-pause, q-quit 
EOF
)

fi

printf "%s\n" "${screen[@]:0:$LINES}"
echo "sampleSum: $sampleSum"
printf "     "
printf "%5s"  ${bins[@]}
printf "  sum bin event\n     "
printf "%5s"  ${binsEx[@]}
printf "  expected bernouli\n      "
printf "%5s"  ${binsXaxis[@]}
printf " sum of 8 events \n\n"
echo  "$summaryText"

if [[ "$frame" == "7" ]];  then
  read  -t .5 -n1 -s x;
  [[ $x == 'r' ]] && resetVars
  [[ $x == 'q' ]] && exit
  [[ $x == 'p' ]] && read -s x
  sum=0
  screen=()
  screenline=0
  ((curSample++))
  sampleSum=0
  curline=0
fi

((frame = (frame+1) % numOfFrames))
sleep $spf 
source downfall.sh $frame $totalVal
