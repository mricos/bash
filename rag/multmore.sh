#!/bin/bash

# Specify files and patterns to be ignored in the recursion
ignore_files=(
    "./out.txt"
    "./example.txt"
    "./data.txt"
    "./*.c.[0-9]*"  # This pattern matches files ending in .c.[integer]
)

# Function to convert array to regex pattern
array_to_regex() {
    local IFS="|"
    echo ".*($*)$"
}

# Function to recursively search for files in directories and concatenate their contents
recurse_dirs() {
    # Build regex pattern for files to ignore
    local ignore_regex=$(array_to_regex "${ignore_files[@]}")

    for file in "${1}"*; do
        if [[ -d "${file}" ]]; then
            recurse_dirs "${file}/"
        elif [[ -f "${file}" && ! "${file}" =~ $ignore_regex ]]; then
            local file_with_path=$(realpath "${file}")
            # Print label with colons and use `cat` to concatenate file content
            echo "::::::::::::"
            echo ${file_with_path}
            echo "::::::::::::"
            cat "${file}"
            echo  # extra newline for better separation
        fi
    done
}

# Start the recursion from the current directory
recurse_dirs "./"
#!/bin/bash

# Specify files and patterns to be ignored in the recursion
ignore_files=(
    "./out.txt"
    "./example.txt"
    "./data.txt"
    "./*.c.[0-9]*"  # This pattern matches files ending in .c.[integer]
)

# Function to convert array to regex pattern
array_to_regex() {
    local IFS="|"
    echo ".*($*)$"
}

# Function to recursively search for files in directories and concatenate their contents
recurse_dirs() {
    # Build regex pattern for files to ignore
    local ignore_regex=$(array_to_regex "${ignore_files[@]}")

    for file in "${1}"*; do
        if [[ -d "${file}" ]]; then
            recurse_dirs "${file}/"
        elif [[ -f "${file}" && ! "${file}" =~ $ignore_regex ]]; then
            local file_with_path=$(realpath "${file}")
            # Print label with colons and use `cat` to concatenate file content
            echo "::::::::::::"
            echo ${file_with_path}
            echo "::::::::::::"
            cat "${file}"
            echo  # extra newline for better separation
        fi
    done
}

# Start the recursion from the current directory
recurse_dirs "./"
