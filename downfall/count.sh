m=0
n=0
bit=0
N=${1:-16}
rowTotals=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colTotals=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colDev=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
colVar=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
while read -r line;
do
  rowtotal=0
  for n in {0..15}
  do  
    bit=${line:$n:1}
    (( rowtotal +=  bit ))
    ((colTotals[n] +=  bit ))
  done
  ((rowTotals[rowtotal] +=  1)) 
  (( m++ ))
done < <(head -$N output.bin | xxd -b -c2 | awk '{print $2$3}')

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
