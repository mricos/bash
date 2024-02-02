# Ensure curl and sed are installed
if ! command -v curl &> /dev/null || ! command -v sed &> /dev/null; then
    echo "This script requires curl and sed. Please install them."
    exit 1
fi

# Function to fetch YouTube video title and store the link
logtime-links-add-youtube() {
    # Check if a URL is provided
    if [ -z "$1" ]; then
        echo "Usage: $0 <YouTube Video URL>"
        exit 1
    fi

    # Define the links file
    LINKS_FILE="$LT_DIR/store/links/$(date +%Y-%m-%d-%H-%M-%S).link"
    # Fetch the HTML content of the YouTube page
    html_content=$(curl -s "$1")

    # Extract the title of the video
    title=$(echo "$html_content" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | sed 's/ - YouTube//')

    # Store the URL, title, and date in the links file
    echo "$1" >> "$LINKS_FILE"
    echo "$title" >> "$LINKS_FILE"
    echo "$(date +%Y-%m-%d)" >> "$LINKS_FILE"
    echo "" >> "$LINKS_FILE"
}


# Function to generate HTML list from stanzas
_logtime_generate_html_list() {
    # Read stanzas from stdin and generate HTML list
    awk 'BEGIN {print "<ul>"} {print "<li>" $0 "</li>"} END {print "</ul>"}'
}

# Function to generate complete HTML page using the stored data
logtime-links-report() {
    # Generate the HTML page
    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Stored Links</title>
</head>
<body>
    <h1>Stored Links</h1>
    $(cat $LT_DIR/store/links/* | _logtime_generate_html_list)
    $(cat $LT_DIR/store/links/* | _logtime_html_info)
</body>
</html>
EOF
}

_logtime_html_info() {
    # Extract the title of the video
    title=$(echo "$html_content" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | sed 's/ - YouTube//')

    # Extract the description that Notion would put in its bookmark for the page
    notion_description=$(echo "$html_content" | sed -n 's/.*<meta property="og:description" content="\([^"]*\)".*/\1/p')

    # Extract the uploader's username
    uploader=$(echo "$html_content" | sed -n 's/.*<meta itemprop="channelId" content="\([^"]*\)".*/\1/p')

    # Extract the video duration
    duration=$(echo "$html_content" | sed -n 's/.*<meta itemprop="duration" content="\([^"]*\)".*/\1/p')

    # Generate a report of the video content
    cat <<EOF
    <h2>Title:</h2>
    <p>$title</p>
    <h2>Uploader:</h2>
    <p>$uploader</p>
    <h2>Duration:</h2>
    <p>$duration</p>
    <h2>Notion Bookmark Description:</h2>
    <p>$notion_description</p>
EOF
}