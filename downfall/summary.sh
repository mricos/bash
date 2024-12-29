if [[ "$frame" == "0" ]];  then
  sampleSummary
  binValue $sampleSum
summaryText=$(cat <<EOF
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
)
fi


