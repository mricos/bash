#!/bin/bash

# Read clipboard content
if command -v wl-paste >/dev/null; then
    clipboard_content=$(wl-paste)
else
    clipboard_content=$(xclip -selection clipboard -o)
fi

# Create SVG wrapper
svg_template='<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1">
  <text x="10" y="20" font-family="Arial" font-size="16" fill="black">
    %s
  </text>
</svg>'

# Escape special characters in clipboard content
escaped_content=$(echo "$clipboard_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g')

# Generate SVG
svg_content=$(printf "$svg_template" "$escaped_content")

# Copy SVG back to clipboard
if command -v wl-copy >/dev/null; then
    echo "$svg_content" | wl-copy
else
    echo "$svg_content" | xclip -selection clipboard
fi

echo "Clipboard content wrapped in SVG and copied back to clipboard."
