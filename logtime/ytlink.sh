#!/bin/bash

# Ensure curl and sed are installed
if ! command -v curl &> /dev/null || ! command -v sed &> /dev/null; then
    echo "This script requires curl and sed. Please install them."
    exit 1
fi

# Check if a URL is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube Video URL>"
    exit 1
fi

# Fetch the HTML content of the YouTube page
html_content=$(curl -s "$1")

# Extract the title of the video
title=$(echo "$html_content" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | sed 's/ - YouTube//')

echo "Title: $title"
