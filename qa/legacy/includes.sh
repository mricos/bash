#!/usr/bin/env bash
# QA Module Includes - Controls what gets loaded for QA functionality

# Prevent multiple loading
if [[ -n "${QA_MODULE_LOADED:-}" ]]; then
    return 0
fi

# Get the directory where this script is located
QA_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the main QA functionality
source "$QA_DIR_PATH/qa.sh"

# Mark as loaded
export QA_MODULE_LOADED=1
