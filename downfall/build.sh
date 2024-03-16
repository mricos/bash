#!/bin/bash

# Export the content of the JavaScript file as an environment variable
export JS_CODE="$(cat js_code.js)"

# Use envsubst to replace the placeholder variables in index.html with their corresponding environment variables
cat index.html.env | envsubst -v JS_CODE  > index.html

