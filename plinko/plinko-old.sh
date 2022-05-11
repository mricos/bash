#source ../utils/utils.sh
source plinko-server.sh
source ./plinko.cfg

plinko-help()
{
  echo "
plinko: the dynamic grid tool for representing data.

Plinko is a set of bash functions used to make 
DOM elements via HTML. The final output is a page
description with functions that can operate on
the grid in a state-like fashion.
"
}
plinko-css(){
  fontsize=$( bc <<< "$NODEHEIGHT/10")  # 10% of size
  midline=$( bc <<< "$NODEHEIGHT/2")  
  nodewidth=$( bc <<< "$NODEHEIGHT/10")  # 10% of size
  nodeheight=$( bc <<< "$NODEHEIGHT/10")  # 10% of size
  

  echo "
.plinko-nodes{
  position:relative;
  margin:auto;
  width:80%;
}
.plinko-node{
  border: 1px solid #888;
  display:block;
  box-sizing:border-box;
  line-height:1em;
  border-radius:50%;
  position:absolute;
  text-align:center;
  
  padding:0;
  margin:0;
  width:$nodewidth;
  width:$nodeheight;
  padding-top:$(bc <<< "$midline - $fontsize")px; 
  font-size:"$fontsize"px;
}
"
}

plinko-node() {
  # extrinsic
  m=$1 
  n=$2
  k=$3 

  #derived
  x=$( bc <<< "$NODEWIDTH * $n + $k")%
  y=$( bc <<< "$NODEWIDTH * $m + $k")%
  echo "<div id="$m-$n-$k" class=\"plinko-node\" onclick=\"plinkoClick(this)\"
    style=\" top:$y; left:$x; \" > $id </div>"
}

plinko-nodes(){
  k=$3 # offset
  echo "<div class=\"plinko-nodes\">"
  for ((i = 0; i < $1; i++)); do
    for ((j = 0; j < $2; j++)); do
      plinko-node $i $j $k
    done
  done
  echo "</div> <!-- plinko-nodes -->"
}


plinko-header() {
  css=$(plinko-css $N $M)
  echo "<!doctype html>
<html>
<head>
  <style>
  $css
  </style>
</head>
<body>
"
}

plinko-js(){
cat <<EOF
<script>
function g(id){
    return document.getElementById(id);
}


function plinkoClick(evt){
    g(evt.id).style.background="blue";
}

function renderNodes(nodes,state){
    nodes[state.curNodeIndex].style.background="blue";
    nodes[state.curRow*10 + state.curCol].style.background="red";
    g('status').innerHTML=state.curRow;
}

let gState={n:0, 
            deltaMs:100,
            curNodeIndex:0,
            curNodeId:"1,1,0",
            curRow:0,
            curCol:0
};

function getState(){
    return gState;
}

document.addEventListener("DOMContentLoaded", function() {
    let nodes = document.getElementsByClassName("plinko-node");
    setInterval(function(){ 
        state=getState();
        if (state.curNodeIndex < nodes.length){
            renderNodes(nodes,state); 
            state.curNodeIndex=state.curNodeIndex+1;
            state.curRow =(state.curNodeIndex+1) % 10;
            state.curCol = Math.floor(Math.random() * 10);
        }
        gState=state;
    }, gState.deltaMs);
});
</script>
EOF
}

plinko-footer(){
  echo "
</body>
</html>
"
}

# This assumes NODEHEIGHT,WEIGHT are set in env!
plinko-create-page(){
  plinko-header
  plinko-js
  echo "<h1> Plinko! </h1>"
  echo "<div id=\"status\"> status </div>"
  for i in "${!1}"
  do 
    $i 
  done
  plinko-footer
}

plinko-build(){
  source plinko.cfg
  m=2;
  n=10;
  outfile="${1:-plinko.html}"
  nodes=("plinko-nodes $m $n  0") # returns big string, not array
  plinko-create-page nodes[@] > "$outfile"  # don't need @ for string
}
