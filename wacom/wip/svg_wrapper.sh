#!/bin/bash

# Set environment variables with defaults if not already set
SVG_FONT_FAMILY="${SVG_FONT_FAMILY:-'Courier New, monospace'}"
SVG_FONT_SIZE="${SVG_FONT_SIZE:-16}"
SVG_TEXT_COLOR="${SVG_TEXT_COLOR:-'#00FF00'}"       # Green text
SVG_BG_COLOR="${SVG_BG_COLOR:-'#000000'}"          # Black background
SVG_BG_OPACITY="${SVG_BG_OPACITY:-0.8}"
SVG_BORDER_COLOR="${SVG_BORDER_COLOR:-'#00FF00'}"   # Green border
SVG_BORDER_WIDTH="${SVG_BORDER_WIDTH:-2}"
SVG_PADDING="${SVG_PADDING:-10}"
SVG_WIDTH="${SVG_WIDTH:-800}"
SVG_HEIGHT="${SVG_HEIGHT:-200}"

# Function to escape special XML characters
escape_xml() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g'
}

# Read clipboard content
if command -v wl-paste >/dev/null; then
    clipboard_content=$(wl-paste)
elif command -v xclip >/dev/null; then
    clipboard_content=$(xclip -selection clipboard -o)
else
    echo "Neither wl-paste nor xclip is installed. Please install one to use this script."
    exit 1
fi

# Escape special characters in clipboard content
escaped_content=$(escape_xml "$clipboard_content")

# Calculate SVG dimensions based on content
IFS=$'\n' read -rd '' -a lines <<< "$clipboard_content"
line_count=${#lines[@]}
font_height=$SVG_FONT_SIZE
svg_width=$SVG_WIDTH
svg_height=$(( SVG_PADDING * 2 + font_height * line_count ))

# Create SVG template with background, border, and text
svg_template='<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="%d" height="%d" viewBox="0 0 %d %d">
  <rect x="0" y="0" width="100%%" height="100%%" style="fill:%s; fill-opacity:%s; stroke:%s; stroke-width:%s;"/>
  %s
</svg>'

# Generate text elements
text_elements=""
y_position=$(( SVG_PADDING + SVG_FONT_SIZE ))
for line in "${lines[@]}"; do
    escaped_line=$(escape_xml "$line")
    text_elements+="  <text x=\"$SVG_PADDING\" y=\"$y_position\" font-family=\"$SVG_FONT_FAMILY\" font-size=\"$SVG_FONT_SIZE\" fill=\"$SVG_TEXT_COLOR\">$escaped_line</text>\n"
    y_position=$(( y_position + SVG_FONT_SIZE ))
done

# Generate SVG content
svg_content=$(printf "$svg_template" "$svg_width" "$svg_height" "$svg_width" "$svg_height" "$SVG_BG_COLOR" "$SVG_BG_OPACITY" "$SVG_BORDER_COLOR" "$SVG_BORDER_WIDTH" "$text_elements")

# Copy SVG back to clipboard
if command -v wl-copy >/dev/null; then
    echo -e "$svg_content" | wl-copy
elif command -v xclip >/dev/null; then
    echo -e "$svg_content" | xclip -selection clipboard
else
    echo "Neither wl-copy nor xclip is installed. Please install one to use this script."
    exit 1
fi

echo "Clipboard content wrapped in SVG with teletype styling and copied back to clipboard."
