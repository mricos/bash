# Create an alias for the 'date' command based on the operating system

[ "$(uname)" = "Darwin" ] && \
    alias date='gdate'  && echo "Darwin/Mac OS uses gdate" 2>&1 

[ ! "$(uname)" = "Darwin" ] && \
    unalias date && echo "Standard date" 2>&1
