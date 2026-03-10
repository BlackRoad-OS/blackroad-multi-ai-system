#!/bin/bash
# Agent Direct Messaging System - Private coordination channels!

MEMORY_DIR="$HOME/.blackroad/memory"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_SYSTEM="${MEMORY_SYSTEM:-${SCRIPT_DIR}/memory-system.sh}"
DM_DIR="$MEMORY_DIR/direct-messages"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Initialize DM system
init_dm() {
    mkdir -p "$DM_DIR/inbox" "$DM_DIR/sent" "$DM_DIR/threads"
    echo -e "${GREEN}✅ DM System initialized${NC}"
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  send <from> <to> <message> - Send DM"
    echo -e "  read <agent> - Read inbox"
}

# Send a DM
send_dm() {
    local from="$1"
    local to="$2"
    local message="$3"

    if [[ -z "$from" || -z "$to" || -z "$message" ]]; then
        echo -e "${YELLOW}Usage: send <from-agent> <to-agent> <message>${NC}"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local msg_id="dm-$(date +%s)-$$"
    
    # Create message file
    cat > "$DM_DIR/inbox/${to}__${msg_id}.json" << EOF
{
    "msg_id": "$msg_id",
    "from": "$from",
    "to": "$to",
    "message": "$message",
    "timestamp": "$timestamp",
    "read": false
}
EOF

    # Save to sent
    cp "$DM_DIR/inbox/${to}__${msg_id}.json" "$DM_DIR/sent/${msg_id}.json"

    echo -e "${GREEN}✅ DM sent to ${CYAN}$to${NC}"

    # Notify in memory
    "$MEMORY_SYSTEM" log dm "$from → $to" "📨 Direct message sent" 2>/dev/null
}

# Check inbox
check_inbox() {
    local agent="${1:-${MY_AGENT:-anonymous}}"
    
    echo -e "${BOLD}${PURPLE}📨 Inbox for ${CYAN}$agent${NC}"
    echo ""
    
    local unread=0
    
    for msg_file in "$DM_DIR/inbox/${agent}__"*.json; do
        [[ ! -f "$msg_file" ]] && continue
        
        local from=$(jq -r '.from' "$msg_file")
        local message=$(jq -r '.message' "$msg_file")
        local timestamp=$(jq -r '.timestamp' "$msg_file")
        local is_read=$(jq -r '.read' "$msg_file")
        
        if [[ "$is_read" == "false" ]]; then
            echo -e "${YELLOW}🆕 NEW${NC} from ${CYAN}$from${NC} ($(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1))"
            unread=$((unread + 1))
        else
            echo -e "    from ${CYAN}$from${NC} ($(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1))"
        fi
        
        echo -e "    ${message:0:60}..."
        echo ""
    done
    
    [[ $unread -eq 0 ]] && echo -e "${GREEN}No new messages${NC}"
}

# Reply to DM
reply() {
    local original_from="$1"
    local message="$2"

    send_dm "${MY_AGENT:-anonymous}" "$original_from" "Re: $message"
}

# Show help
show_help() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${CYAN}║      📨 BlackRoad Direct Messaging - Help                 ║${NC}
${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

${GREEN}USAGE:${NC}
    $0 <command> [options]

${GREEN}COMMANDS:${NC}

${CYAN}init${NC}
    Initialize the DM system

${CYAN}send${NC} <from> <to> <message>
    Send a direct message
    Example: $0 send alice-agent bob-agent "Hey Bob!"

${CYAN}read${NC} <agent>
    Read messages for an agent
    Example: $0 read bob-agent

${CYAN}reply${NC} <to-agent> <message>
    Reply to an agent (uses MY_AGENT env var as sender)

EOF
}

# Main command router
case "$1" in
    init)
        init_dm
        ;;
    send)
        mkdir -p "$DM_DIR/inbox" "$DM_DIR/sent" "$DM_DIR/threads"
        send_dm "$2" "$3" "$4"
        ;;
    read|check)
        mkdir -p "$DM_DIR/inbox" "$DM_DIR/sent" "$DM_DIR/threads"
        check_inbox "$2"
        ;;
    reply)
        mkdir -p "$DM_DIR/inbox" "$DM_DIR/sent" "$DM_DIR/threads"
        reply "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [[ -z "$1" ]]; then
            show_help
        else
            echo -e "${YELLOW}Unknown command: $1${NC}"
            show_help
            exit 1
        fi
        ;;
esac
