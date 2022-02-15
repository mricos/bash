function repeat(){
  for ((i=0;i<$1;i++)); do
    eval ${*:2}
  done
}

function sum(){
  total=0
  for i in ${*:1}
  do
    total=$(expr $total + $i)
  done
  echo $total
}

function resetVars(){
dec2bin=( {0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
curSample=1
curEvent=0
totalVal=0
sampleSum=0
colTotals=()
rowkTotals=()
bins=(0 0 0 0 0 0 0 0)
M=()
screen=()
binSize=256
numEvents=2048
numBins=16
}

[ -z "$1" ] && resetVars

function screenToMatrix(){
  M=($(printf "%s\n" "${screen[@]}" | awk '{print $3 "\n" }'))
}
function totalOnesByRow(){
  bits=${1//1/1 }; # substitute 10010 as 1 00 1 0
  sum $bits
}

function totalOnesByColInM(){
  #M=(${*:1})
  numRows="${#M[@]}"
  numCols="${#M[0]}"

  for ((r=0;r<numRows;r++)); do
    row="${M[$r]}"
    echo
    echo "Row $r" && read x
    for ((c=0;c<numCols;c++)); do
      b=${row:$c:1}
      echo "$b: before: ${colTotals[@]}"
      ((colTotals[c]=colTotals[c] + b  ))
      echo "$b: after: ${colTotals[@]}"
      read x
    done
  done

  echo colTotals: "${colTotals[@]}"
}

function tallyColSumOfRow(){
  row=$1
  for ((c=0;c<numCols;c++)); do
    b=${row:$c:1}
    ((colTotals[c]=colTotals[c] + b  ))
  done
}

binValue(){
  for (( n=0;n<numBins;n++ )); do
    if (( "$1" < (( (n+1)*(1<<8))) )); then 
        ((bins[n]=bins[n] + 1 ))
        break
    fi
  done
}

totalVal=${2:-$totalVal}
spf=.1
frame=$1
numOfFrames=8
time=$(date +%s%N)
curline=$frame
readarray -t a screen < ./screen.txt


# Record event of current sample
# -vAn -> supress index
# -N1  -> single char smallest possible request of /dev/urandom
val=$(od -vAn -N1 -td < /dev/random) && ((curEvent++))

valOnes="$(totalOnesByRow ${dec2bin[$val]})"
((totalVal = totalVal + $val))
((sampleSum = sampleSum + $val))
screen[$curline]=\
"$(printf "%5s %5s %s %s" \
$curline $val ${dec2bin[$val]} $valOnes)"
screenToMatrix
printf "%s\n" "${screen[@]}" > ./screen.txt

clear
header="($time, $spf, $frame, $LINES, $COLUMNS)"
((w= COLUMNS-${#header[@]}))
printf "%${w}s\n\n" "$header"
printf "%s\n" "${screen[@]}"

repeat $(( LINES/2 - curline -4))  echo ""
echo "bins: ${bins[@]}"
echo
#repeat $(( LINES/2 - curline -2 ))  echo ""

((expectedColVal=curSample*numCols/2))
echo "curSample: $curSample"
echo "curEvent: $curEvent"
echo "exectedColVal: $expectedColVal"
tallyColSumOfRow ${dec2bin[$val]}
echo "colTotals: ${colTotals[@]}"


colError=()
for ((c=0;c<numCols;c++)); do
  ((colError[c] = colTotals[c] - expectedColVal ))
done
colErrorVar=()
for ((c=0;c<numCols;c++)); do
  ((colVar[c] = colTotals[c] - expectedColVal ))
done

colVar=0
for ((c=0;c<numCols;c++)); do
  ((colVar = colVar + (colTotals[c] - expectedColVal)*\
                       (colTotals[c] - expectedColVal) / $curSample  ))
done


echo "colError: ${colError[@]}"
echo "colVar: $colVar"

echo "sampleSum: $sampleSum"
echo "totalVal: $totalVal"

if [[ "$frame" == "7" ]];  then
   binValue $sampleSum
   sampleSum=0
  ((curSample++))
  #read -s x
  [[ $x = 'r' ]] && resetVars
  cat /dev/null > ./screen.txt
  sum=0
  screen=()
fi

((frame = (frame+1) % numOfFrames))
sleep $spf 

source downfall.sh $frame
