#!/usr/bin/env bash

# QA REPL with MELVIN integration and multicursor support
# Supports prefix commands: ! (bash), @ (status), / ./ (files), * (multicursor)

set -euo pipefail

# Color definitions (minimal, following TKM pattern)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Unicode symbols for better UX
readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="💡"
readonly MULTICURSOR="🎯"
readonly ANALYTICS="📊"

# REPL state
QA_REPL_HISTORY_FILE="$HOME/.qa_repl_history"
QA_REPL_RUNNING=false
MELVIN_ENABLED=false
MULTICURSOR_ENABLED=false

# Source the core QA system
source "$(dirname "${BASH_SOURCE[0]}")/qa.sh"

# Check for optional integrations
_qa_repl_check_integrations() {
    # Check MELVIN availability
    if command -v melvin >/dev/null 2>&1; then
        if [[ -f "$HOME/src/bash/melvin/melvin.sh" ]]; then
            source "$HOME/src/bash/melvin/melvin.sh" 2>/dev/null && MELVIN_ENABLED=true
        fi
    fi

    # Check multicursor/RAG availability
    if [[ -d "$HOME/src/bash/rag" && -f "$HOME/src/bash/rag/bash/multicat.sh" ]]; then
        # Source RAG tools
        for tool in multicat multisplit multifind; do
            [[ -f "$HOME/src/bash/rag/bash/${tool}.sh" ]] && source "$HOME/src/bash/rag/bash/${tool}.sh"
        done
        MULTICURSOR_ENABLED=true
    fi
}

# Initialize REPL environment
_qa_repl_init() {
    _qa_repl_check_integrations

    # Initialize history
    touch "$QA_REPL_HISTORY_FILE"

    # Set up bash completion if available
    if command -v complete >/dev/null; then
        complete -F _qa_repl_completion qa_repl
    fi

    QA_REPL_RUNNING=true
}

# Generate dynamic prompt
_qa_repl_get_prompt() {
    local context_info=""
    local status_indicators=""

    # Show current context if available
    if [[ -n "$(_get_qa_context 2>/dev/null || true)" ]]; then
        context_info="ctx"
    fi

    # Show integration status
    [[ "$MELVIN_ENABLED" == "true" ]] && status_indicators="${status_indicators}${ANALYTICS}"
    [[ "$MULTICURSOR_ENABLED" == "true" ]] && status_indicators="${status_indicators}${MULTICURSOR}"

    # Construct prompt
    local prompt="qa"
    [[ -n "$context_info" ]] && prompt="${prompt}:${context_info}"
    [[ -n "$status_indicators" ]] && prompt="${prompt} ${status_indicators}"
    echo "${prompt}> "
}

# Handle bash commands (! prefix)
_qa_repl_handle_bash() {
    local input="$1"
    local bash_cmd="${input#!}"

    if [[ -n "$bash_cmd" ]]; then
        echo -e "${BLUE}Running:${NC} $bash_cmd"
        eval "$bash_cmd"
    else
        echo "Usage: !<command>"
        echo "Example: !ls, !grep pattern file, !date"
    fi
}

# Handle status commands (@ prefix)
_qa_repl_handle_status() {
    local input="$1"
    local status_cmd="${input#@}"

    case "$status_cmd" in
        ""|"all")
            _qa_repl_show_full_status
            ;;
        "qa"|"system")
            qa_status
            ;;
        "melvin")
            if [[ "$MELVIN_ENABLED" == "true" ]]; then
                melvin status qa 2>/dev/null || echo "MELVIN: Available but not initialized"
            else
                echo "MELVIN: Not available"
            fi
            ;;
        "multicursor"|"mc")
            _qa_repl_multicursor_status
            ;;
        "integrations")
            echo "Integration Status:"
            echo "  QA System: ${CHECK} Active"
            echo "  MELVIN: $([[ "$MELVIN_ENABLED" == "true" ]] && echo "${CHECK} Enabled" || echo "${CROSS} Disabled")"
            echo "  Multicursor: $([[ "$MULTICURSOR_ENABLED" == "true" ]] && echo "${CHECK} Enabled" || echo "${CROSS} Disabled")"
            ;;
        *)
            echo "Available status commands:"
            echo "  @all         - Complete system status"
            echo "  @qa          - QA system status"
            echo "  @melvin      - MELVIN analytics status"
            echo "  @mc          - Multicursor system status"
            echo "  @integrations- Integration status"
            ;;
    esac
}

# Handle file operations (/ and ./ prefixes)
_qa_repl_handle_files() {
    local input="$1"

    if [[ "$input" =~ ^\./ ]]; then
        local file_path="${input#./}"
        # Handle relative path
        if [[ -f "$file_path" ]]; then
            echo -e "${INFO} Showing: ./$file_path"
            head -20 "$file_path"
            echo "..."
        else
            echo -e "${CROSS} File not found: ./$file_path"
        fi
    elif [[ "$input" =~ ^/ ]]; then
        local file_path="$input"
        # Handle absolute path
        if [[ -f "$file_path" ]]; then
            echo -e "${INFO} Showing: $file_path"
            head -20 "$file_path"
            echo "..."
        else
            echo -e "${CROSS} File not found: $file_path"
        fi
    fi
}

# Handle multicursor operations (* prefix)
_qa_repl_handle_multicursor() {
    local input="$1"
    local mc_cmd="${input#*}"

    if [[ "$MULTICURSOR_ENABLED" != "true" ]]; then
        echo -e "${CROSS} Multicursor system not available"
        echo "Ensure ~/src/bash/rag is accessible"
        return 1
    fi

    # Parse *target.operation format
    if [[ "$mc_cmd" =~ ^([^.]+)\.(.+)$ ]]; then
        local target="${BASH_REMATCH[1]}"
        local operation="${BASH_REMATCH[2]}"
        _qa_repl_multicursor_operation "$target" "$operation"
    elif [[ -n "$mc_cmd" ]]; then
        _qa_repl_multicursor_overview "$mc_cmd"
    else
        _qa_repl_multicursor_help
    fi
}

# Execute multicursor operation
_qa_repl_multicursor_operation() {
    local target="$1"
    local operation="$2"

    echo -e "${MULTICURSOR} Multicursor: $target.$operation"

    case "$operation" in
        "list"|"ls")
            _qa_repl_multicursor_list "$target"
            ;;
        "create"|"new")
            echo "Creating multicursor collection: $target"
            # Implementation would create new collection
            echo "Not yet implemented - would create collection '$target'"
            ;;
        "info"|"show")
            _qa_repl_multicursor_show "$target"
            ;;
        "edit")
            echo "Editing multicursor: $target"
            echo "Not yet implemented - would open $target for editing"
            ;;
        "search"|"find")
            echo "Searching multicursor: $target"
            echo "Not yet implemented - would search within $target collection"
            ;;
        "export")
            echo "Exporting multicursor: $target"
            echo "Not yet implemented - would export $target to MULTICAT format"
            ;;
        *)
            echo -e "${WARNING} Unknown multicursor operation: $operation"
            _qa_repl_multicursor_help
            ;;
    esac
}

# Show multicursor overview
_qa_repl_multicursor_overview() {
    local target="$1"
    echo -e "${MULTICURSOR} Multicursor overview: $target"
    echo "Available operations for '$target':"
    echo "  *.list     - List collections"
    echo "  *.info     - Show detailed info"
    echo "  *.create   - Create new collection"
    echo "  *.edit     - Edit collection"
    echo "  *.search   - Search within collection"
    echo "  *.export   - Export to MULTICAT"
}

# Multicursor help
_qa_repl_multicursor_help() {
    echo "Multicursor Commands (* prefix):"
    echo "  *list              - List all collections"
    echo "  *<name>.info       - Show collection details"
    echo "  *<name>.create     - Create new collection"
    echo "  *<name>.edit       - Edit collection"
    echo "  *<name>.search     - Search collection"
    echo "  *<name>.export     - Export collection"
    echo ""
    echo "Examples:"
    echo "  *python.info       - Show Python-related cursors"
    echo "  *debug.search      - Search debugging collections"
    echo "  *all.list          - List all multicursor collections"
}

# Multicursor status
_qa_repl_multicursor_status() {
    if [[ "$MULTICURSOR_ENABLED" != "true" ]]; then
        echo "Multicursor: ${CROSS} Not available"
        return
    fi

    echo "Multicursor System Status:"

    # Check for RAG directory
    if [[ -d "$HOME/.rag" ]]; then
        local cursor_count=$(find "$HOME/.rag/cursors" -name "*.json" 2>/dev/null | wc -l || echo 0)
        local collection_count=$(find "$HOME/.rag/multicursor" -name "*.json" 2>/dev/null | wc -l || echo 0)
        echo "  Individual cursors: $cursor_count"
        echo "  Collections: $collection_count"
    else
        echo "  RAG directory: Not initialized"
    fi
}

# Show full system status
_qa_repl_show_full_status() {
    echo "=== QA REPL System Status ==="
    echo ""

    # QA System
    echo -e "${GREEN}QA System:${NC}"
    qa_status
    echo ""

    # MELVIN Analytics
    echo -e "${GREEN}MELVIN Analytics:${NC}"
    if [[ "$MELVIN_ENABLED" == "true" ]]; then
        melvin status qa 2>/dev/null || echo "  Available but not registered"
    else
        echo "  ${CROSS} Not available"
    fi
    echo ""

    # Multicursor System
    echo -e "${GREEN}Multicursor System:${NC}"
    _qa_repl_multicursor_status
}

# Process REPL commands
_qa_repl_process_command() {
    local input="$1"

    # Skip empty input
    [[ -z "$input" ]] && return 0

    # Add to history
    echo "$input" >> "$QA_REPL_HISTORY_FILE"

    # Handle prefix commands
    case "$input" in
        # Bash commands (check first before multicursor)
        !*)
            _qa_repl_handle_bash "$input"
            return 0
            ;;
        # Status commands
        @*)
            _qa_repl_handle_status "$input"
            return 0
            ;;
        # File operations
        ./*|/*)
            _qa_repl_handle_files "$input"
            return 0
            ;;
        # Multicursor operations (check last to avoid conflicts)
        \\**)
            _qa_repl_handle_multicursor "$input"
            return 0
            ;;
    esac

    # Parse command and arguments
    local cmd
    local args
    read -r cmd args <<< "$input"

    # Handle core QA commands
    case "$cmd" in
        qq|query)
            [[ -n "$args" ]] && qq "$args" || echo "Usage: qq <question>"
            ;;
        a|answer)
            a ${args:-0}
            ;;
        q|question)
            q ${args:-0}
            ;;
        tag)
            if [[ -n "$args" ]]; then
                qa_tag $args
            else
                echo "Usage: tag <id> <tags>"
            fi
            ;;
        # MELVIN analytics commands
        tokens|cost|queries)
            if [[ "$MELVIN_ENABLED" == "true" ]]; then
                melvin qa.$cmd $args
            else
                echo -e "${WARNING} MELVIN analytics not available"
                echo "Analytics commands require MELVIN integration"
            fi
            ;;
        # Core REPL commands
        help|h)
            _qa_repl_show_help
            ;;
        status)
            _qa_repl_show_full_status
            ;;
        history)
            echo "Recent commands:"
            tail -10 "$QA_REPL_HISTORY_FILE" 2>/dev/null | nl || echo "No history available"
            ;;
        clear)
            clear
            _qa_repl_show_banner
            ;;
        exit|quit|q!)
            echo -e "${GREEN}Goodbye!${NC}"
            QA_REPL_RUNNING=false
            ;;
        "")
            # Empty command, do nothing
            ;;
        *)
            echo -e "${WARNING} Unknown command: $cmd"
            echo "Type 'help' for available commands"
            ;;
    esac
}

# Show REPL help
_qa_repl_show_help() {
    echo "QA REPL Commands:"
    echo ""
    echo -e "${CYAN}Core QA Commands:${NC}"
    echo "  qq <query>         - Ask question"
    echo "  a [n]              - Show nth recent answer (default: 0)"
    echo "  q [n]              - Show nth recent question"
    echo "  tag <id> <tags>    - Add tags to query"
    echo ""

    if [[ "$MELVIN_ENABLED" == "true" ]]; then
        echo -e "${CYAN}MELVIN Analytics:${NC}"
        echo "  tokens by <dim>    - Token usage analysis"
        echo "  cost by <dim>      - Cost analysis"
        echo "  queries by <dim>   - Query count analysis"
        echo "  Available dimensions: engine, day, hour, context, tag"
        echo ""
    fi

    echo -e "${CYAN}Prefix Commands:${NC}"
    echo "  !<command>         - Execute bash command"
    echo "  @<status>          - Show system status"
    echo "  /<path> or ./<path>- Show file contents"
    if [[ "$MULTICURSOR_ENABLED" == "true" ]]; then
        echo "  *<target>.<op>     - Multicursor operations"
    fi
    echo ""

    echo -e "${CYAN}REPL Commands:${NC}"
    echo "  help               - Show this help"
    echo "  status             - Show system status"
    echo "  history            - Show command history"
    echo "  clear              - Clear screen"
    echo "  exit               - Exit REPL"
    echo ""

    echo -e "${CYAN}Examples:${NC}"
    echo "  qq 'How do I sort in Python?'"
    echo "  a                  # Show last answer"
    echo "  !date              # Run bash command"
    echo "  @melvin            # Show MELVIN status"
    echo "  ./README.md        # Show file contents"
    if [[ "$MULTICURSOR_ENABLED" == "true" ]]; then
        echo "  *python.info       # Show Python multicursors"
    fi
    if [[ "$MELVIN_ENABLED" == "true" ]]; then
        echo "  cost by engine     # Show costs by AI engine"
    fi
}

# Show startup banner
_qa_repl_show_banner() {
    echo -e "${GREEN}QA Interactive REPL${NC}"
    echo -e "Type ${CYAN}'help'${NC} for commands, ${CYAN}'exit'${NC} to quit"

    local integrations=""
    [[ "$MELVIN_ENABLED" == "true" ]] && integrations="${integrations} ${ANALYTICS}Analytics"
    [[ "$MULTICURSOR_ENABLED" == "true" ]] && integrations="${integrations} ${MULTICURSOR}Multicursor"
    [[ -n "$integrations" ]] && echo -e "Enabled:$integrations"

    echo -e "Prefixes: ${CYAN}!${NC}command ${CYAN}@${NC}status ${CYAN}./${NC}file"
    [[ "$MULTICURSOR_ENABLED" == "true" ]] && echo -ne " ${CYAN}*${NC}multicursor"
    echo ""
}

# Tab completion function
_qa_repl_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    local qa_commands="qq query a answer q question tag help status history clear exit quit"
    local status_commands="all qa melvin mc multicursor integrations"
    local melvin_commands="tokens cost queries"
    local multicursor_targets="list all python debug devops"
    local multicursor_operations="list info create edit search export"

    # Handle prefix completions
    case "$cur" in
        @*)
            local status_cur="${cur#@}"
            COMPREPLY=($(compgen -W "$status_commands" -- "$status_cur"))
            # Add @ prefix back
            for ((i=0; i<${#COMPREPLY[@]}; i++)); do
                COMPREPLY[i]="@${COMPREPLY[i]}"
            done
            return
            ;;
        \\**)
            if [[ "$MULTICURSOR_ENABLED" == "true" ]]; then
                local mc_cur="${cur#*}"
                if [[ "$mc_cur" =~ ^([^.]+)\.(.*)$ ]]; then
                    local target="${BASH_REMATCH[1]}"
                    local op="${BASH_REMATCH[2]}"
                    COMPREPLY=($(compgen -W "$multicursor_operations" -- "$op"))
                else
                    local target_suggestions=""
                    for target in $multicursor_targets; do
                        if [[ "$target" =~ ^$mc_cur ]]; then
                            target_suggestions="$target_suggestions $target."
                        fi
                    done
                    COMPREPLY=($(compgen -W "$target_suggestions" -- "$mc_cur"))
                fi
                # Add * prefix back
                for ((i=0; i<${#COMPREPLY[@]}; i++)); do
                    COMPREPLY[i]="*${COMPREPLY[i]}"
                done
            fi
            return
            ;;
        ./*)
            # File completion for relative paths
            local file_cur="${cur#./}"
            COMPREPLY=($(compgen -f -- "$file_cur"))
            for ((i=0; i<${#COMPREPLY[@]}; i++)); do
                COMPREPLY[i]="./${COMPREPLY[i]}"
            done
            return
            ;;
        /*)
            # File completion for absolute paths
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
    esac

    # Handle regular command completion
    if [[ ${#COMP_WORDS[@]} -eq 2 ]]; then
        # First word completion
        local all_commands="$qa_commands"
        [[ "$MELVIN_ENABLED" == "true" ]] && all_commands="$all_commands $melvin_commands"
        COMPREPLY=($(compgen -W "$all_commands" -- "$cur"))
    else
        # Context-specific completion
        case "$prev" in
            tokens|cost|queries)
                if [[ "$MELVIN_ENABLED" == "true" ]]; then
                    COMPREPLY=($(compgen -W "by" -- "$cur"))
                fi
                ;;
            by)
                if [[ "$MELVIN_ENABLED" == "true" ]]; then
                    COMPREPLY=($(compgen -W "engine day hour context tag user" -- "$cur"))
                fi
                ;;
        esac
    fi
}

# Main REPL function
qa_repl() {
    _qa_repl_init
    _qa_repl_show_banner

    while [[ "$QA_REPL_RUNNING" == "true" ]]; do
        local input
        read -r -p "$(_qa_repl_get_prompt)" -e input
        _qa_repl_process_command "$input"
    done
}

# Utility functions for external integration
qa_repl_list() {
    echo "Available multicursor collections:"
    # Implementation would list actual collections
    echo "(Implementation pending)"
}

qa_repl_status() {
    _qa_repl_show_full_status
}

# Export functions for external use
export -f qa_repl qa_repl_status qa_repl_list

# Start REPL if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    qa_repl
fi