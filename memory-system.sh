#!/bin/bash

# BlackRoad Memory System - Journal & Logging Backbone
# Records all agent actions to a persistent JSONL journal.
# Usage: memory-system.sh log <action> <entity> <message>

MEMORY_DIR="${BLACKROAD_MEMORY_DIR:-$HOME/.blackroad/memory}"
JOURNAL_DIR="$MEMORY_DIR/journals"
MASTER_JOURNAL="$JOURNAL_DIR/master-journal.jsonl"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure journal directory exists
init_memory() {
    mkdir -p "$JOURNAL_DIR"
    touch "$MASTER_JOURNAL"
}

# Portable SHA-256: try sha256sum (Linux) then shasum (macOS)
sha256_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
    else
        echo "ERROR: neither sha256sum nor shasum found" >&2
        return 1
    fi
}

# Log an action to the master journal
log_action() {
    local action="$1"
    local entity="$2"
    local message="$3"

    if [[ -z "$action" || -z "$entity" ]]; then
        echo -e "${RED}Usage: memory-system.sh log <action> <entity> <message>${NC}" >&2
        return 1
    fi

    init_memory

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Escape double quotes in fields
    local safe_action="${action//\"/\\\"}"
    local safe_entity="${entity//\"/\\\"}"
    local safe_message="${message//\"/\\\"}"

    local entry="{\"action\":\"${safe_action}\",\"entity\":\"${safe_entity}\",\"message\":\"${safe_message}\",\"timestamp\":\"${timestamp}\"}"

    echo "$entry" >> "$MASTER_JOURNAL"
}

# Show recent journal entries
show_recent() {
    local count="${1:-20}"
    init_memory

    if [[ ! -s "$MASTER_JOURNAL" ]]; then
        echo -e "${YELLOW}No journal entries yet.${NC}"
        return
    fi

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         📖 BLACKROAD MEMORY JOURNAL                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    tail -"$count" "$MASTER_JOURNAL" | while IFS= read -r line; do
        local action entity message timestamp
        action=$(echo "$line" | jq -r '.action' 2>/dev/null)
        entity=$(echo "$line" | jq -r '.entity' 2>/dev/null)
        message=$(echo "$line" | jq -r '.message' 2>/dev/null)
        timestamp=$(echo "$line" | jq -r '.timestamp' 2>/dev/null)

        echo -e "  ${CYAN}[$timestamp]${NC} ${GREEN}$action${NC} → ${YELLOW}$entity${NC}"
        [[ -n "$message" && "$message" != "null" ]] && echo -e "    $message"
    done

    echo ""
    local total
    total=$(wc -l < "$MASTER_JOURNAL" | tr -d ' ')
    echo -e "${GREEN}Total journal entries: $total${NC}"
}

# Show statistics from journal
show_stats() {
    init_memory

    if [[ ! -s "$MASTER_JOURNAL" ]]; then
        echo -e "${YELLOW}No journal entries yet.${NC}"
        return
    fi

    echo -e "${CYAN}Journal Statistics:${NC}"
    local total
    total=$(wc -l < "$MASTER_JOURNAL" | tr -d ' ')
    echo -e "  Total entries: ${GREEN}$total${NC}"

    echo -e "  Top actions:"
    jq -r '.action' "$MASTER_JOURNAL" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
        while read -r count action; do
            echo -e "    ${YELLOW}$action${NC}: $count"
        done
}

# Show help
show_help() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${CYAN}║       📖 BlackRoad Memory System - Help                   ║${NC}
${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

${GREEN}USAGE:${NC}
    $0 <command> [options]

${GREEN}COMMANDS:${NC}

${CYAN}log${NC} <action> <entity> <message>
    Record an action to the master journal
    Example: $0 log task-completed my-agent "Task done"

${CYAN}recent${NC} [count]
    Show recent journal entries (default: 20)
    Example: $0 recent 50

${CYAN}stats${NC}
    Show journal statistics

${GREEN}JOURNAL LOCATION:${NC}
    ${MASTER_JOURNAL}

EOF
}

# Main command router
case "$1" in
    log)
        log_action "$2" "$3" "$4"
        ;;
    recent)
        show_recent "${2:-20}"
        ;;
    stats)
        show_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [[ -n "$1" ]]; then
            echo -e "${RED}Unknown command: $1${NC}" >&2
        fi
        show_help
        exit 1
        ;;
esac
