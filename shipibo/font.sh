#!/bin/bash

# Function to list all available fonts (requires fc-list)
shipibo_list_terminal_fonts() {
    if ! command -v fc-list &> /dev/null; then
        echo "fc-list not found. Install fontconfig (e.g., brew install fontconfig)."
        return 1
    fi
    fc-list : family | sort | uniq
}

# Function to list existing Terminal profiles
shipibo_list_terminal_profiles() {
    defaults read com.apple.Terminal "Window Settings" | grep -E '^[[:space:]]*"[^"]+"' | sed -E 's/^[[:space:]]*"([^"]+)".*/\1/'
}

# Create a new Terminal profile by copying an existing one
# Usage: create_terminal_profile "Base Profile" "New Profile"
shipibo_create_terminal_profile() {
    local base_profile="$1"
    local new_profile="$2"
    
    if [[ -z $base_profile || -z $new_profile ]]; then
        echo "Usage: create_terminal_profile <base_profile> <new_profile>"
        return 1
    fi

    /usr/libexec/PlistBuddy -c "Copy :Window\ Settings:$base_profile :Window\ Settings:$new_profile" ~/Library/Preferences/com.apple.Terminal.plist
    echo "Created profile '$new_profile' based on '$base_profile'"
    
    # Make sure Terminal reads updated plist
    killall Terminal &>/dev/null
}

# Set font and size for a specific Terminal profile
# Usage: set_terminal_font "ProfileName" "FontName" FontSize
shipibo_set_terminal_font() {
    local profile="$1"
    local font_name="$2"
    local font_size="$3"

    if [[ -z $profile || -z $font_name || -z $font_size ]]; then
        echo "Usage: set_terminal_font <profile> <font_name> <font_size>"
        return 1
    fi

    font_spec="${font_name} ${font_size}"
    defaults write com.apple.Terminal "Window Settings" -dict-add "$profile" "$(defaults read com.apple.Terminal "Window Settings" | plutil -convert xml1 - -o - | grep -A 1000 "<key>$profile</key>" | plutil -extract "$profile" xml1 -o - - | plutil -insert 'Font' -string "$font_spec" - -o - | plutil -convert binary1 - -o /tmp/termprofile.plist)"
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$profile:FontName \"$font_name\"" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$profile:FontSize $font_size" ~/Library/Preferences/com.apple.Terminal.plist

    echo "Set font to '$font_name' size $font_size for profile '$profile'"
    
    killall Terminal &>/dev/null
}

# Set default Terminal profile
# Usage: set_default_terminal_profile "Profile Name"
shipibo_set_default_terminal_profile() {
    local profile="$1"
    defaults write com.apple.Terminal "Default Window Settings" -string "$profile"
    defaults write com.apple.Terminal "Startup Window Settings" -string "$profile"
    echo "Set '$profile' as default Terminal profile"
    killall Terminal &>/dev/null
}

# Enable Arimo Nerd Font in a new Terminal profile
shipibo_enable_arimo_nerd_font() {
    local base_profile="Basic"
    local nerd_profile="ArimoNerdFont"
    local nerd_font="Arimo Nerd Font Mono"
    local font_size=14

    echo "Creating Nerd Font terminal profile..."

    shipibo_create_terminal_profile "$base_profile" "$nerd_profile" || return 1
    set_terminal_font "$nerd_profile" "$nerd_font" "$font_size" || return 1
    set_default_terminal_profile "$nerd_profile" || return 1

    echo "✅ Arimo Nerd Font profile '$nerd_profile' created and set as default."
}
