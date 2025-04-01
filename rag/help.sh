mcat_help() {
  cat <<EOF
multicat: Concatenate files into a multicat stream with metadata headers.
Usage: \$(basename "$0") [OPTIONS] [FILES_OR_DIRECTORIES...]

Options:
  -i FILE_OR_DIR  Include one or more files or directories. Can be used
                  multiple times. Equivalent to adding files/dirs at the end.
  -f FILE         Load list of files or directories from the given file.
  -x FILE         Load exclusion patterns from the specified file.
  -r              Recursively process directories.
  -h, --help      Display this help message.

Description:
  Processes specified files and, if -r is used, files within specified
  directories. Exclusion patterns from .gitignore and .multignore files
  found in the current directory and subdirectories are loaded.

  Output includes a header block for each file:
    #MULTICAT_START#
    # dir: /original/path/to/dir
    # file: filename.txt
    # notes:
    #MULTICAT_END#
  followed by the file contents.

Examples:
  \$(basename "$0") file1.txt dir1/
  \$(basename "$0") -r dir1/ file2.txt
  \$(basename "$0") -f my_files.txt -r
  \$(basename "$0") -x ignore.txt -r dir1/
EOF
}
