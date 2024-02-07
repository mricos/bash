# Create an alias for the 'date' command based on the operating system
[[ "$(uname)" == "Darwin" ]] && alias date='gdate'
