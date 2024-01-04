#!/bin/bash

# Function to test connectivity with OpenAI API
test_openai_connectivity() {
    # Hardcoded API key - replace with your actual API key
    local api_key=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
    echo "Using api_key: $api_key"
    # OpenAI API endpoint
    local api_endpoint="https://api.openai.com/v1/completions"

    # The model to use for the query
    local model="text-davinci-003"

    # Simple query - asking for the current date and time
    local query="What is the current date and time?"

    # Prepare the data for the POST request
# Prepare the data for the POST request
local data=$(jq -nc \
  --arg model "$model" \
  --arg prompt "$query" \
  --argjson max_tokens 10 \
  '{model: $model, prompt: $prompt, max_tokens: $max_tokens}')

    # Make the request to OpenAI API
    local response=$(curl -s \
      -X POST "$api_endpoint" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json" \
      -d "$data")

    # Extract and print the response
    local answer=$(echo "$response" | jq -r '.choices[0].text')
    echo "Response from OpenAI: $answer"
    echo "Full Response: $response"
}

# Call the function to test connectivity
test_openai_connectivity
