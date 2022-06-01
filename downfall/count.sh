m=0
n=0
bit=0
N=${1:-16}
rowTotals=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colTotals=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colDev=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colVar=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )

src=/dev/urandom
while read -r line;
do
  rowtotal=0
  for n in {0..15}  # 16 bits
  do  
    bit=${line:$n:1} # offset=n, len=1 (0 or 1)
    (( rowtotal +=  bit ))
    ((colTotals[n] +=  bit ))  # every bit should be 50/50 e.g. 8/16
  done
  ((rowTotals[rowtotal] +=  1))  # 0, 1, 2 .. 14, 15
  (( m++ )) # m=row# pointing to  16bitword
done < <(xxd -b -c2 $src | head -$N |  awk '{print $2$3}') # read 2 bytes

col_mean_hat=$(( m/2 ))

for n in {0..15}
do  
  (( colDev[n] = colTotals[n] - col_mean_hat ))
  (( colVar[n] = (colDev[n] * colDev[n]) / N ))
done

echo "$N rows"
echo "col_mean_hat: $m / 2 = $col_mean_hat"
echo "row totals: ${rowTotals[@]}"
echo "col totals: ${colTotals[@]}"
echo "col mean : ${colDev[@]}"
echo "col variance: ${colVar[@]}"

count-json(){
echo "["
for n in {0..15}
do
  echo "{"
  echo "\"name\":$n,"
  echo "\"val\":${rowTotals[$n]}"
  printf "}"
  if [[ $n != 15 ]]; then printf ","; fi
  echo ""
done
echo "]"
}

