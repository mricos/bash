logtime-store(){
  echo "$(date +%s) $@" >> $LT_DIR/store/$LT_START.store
}

logtime-stores(){
  cat $LT_DIR/store/$LT_START.store
}

