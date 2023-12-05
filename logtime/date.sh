# Create an alias for the 'date' command based on the operating system
if [ "$(uname)" = "Darwin" ]; then
    # macOS uses a different syntax for 'date'
    alias date='gdate'
else
    # Linux and other Unix-like systems
    echo Standard Linux
fi
echo Using $(uname) for OS.
