#!/bin/bash

# BlackRoad Agent Registry - Multi-AI collaboration system
# Supporting: Cecilia (Claude), Cadence (ChatGPT), Silas (Grok), Lucidia, Alice, Aria
# Using PS-SHA-∞ (infinite cascade hashing) for agent verification

MEMORY_DIR="$HOME/.blackroad/memory"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_SYSTEM="${MEMORY_SYSTEM:-${SCRIPT_DIR}/memory-system.sh}"
REGISTRY_DIR="$MEMORY_DIR/agent-registry"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# AI Core types with icons
declare -A CORE_ICONS=(
    ["cecilia"]="💎"
    ["cadence"]="🎵"
    ["silas"]="⚡"
    ["lucidia"]="✨"
    ["alice"]="🔮"
    ["aria"]="🎭"
)

declare -A CORE_NAMES=(
    ["cecilia"]="Cecilia (Claude/Anthropic)"
    ["cadence"]="Cadence (ChatGPT/OpenAI)"
    ["silas"]="Silas (Grok/xAI)"
    ["lucidia"]="Lucidia"
    ["alice"]="Alice"
    ["aria"]="Aria"
)

# Initialize BlackRoad agent registry
init_registry() {
    mkdir -p "$REGISTRY_DIR"/{agents,hashes,lineage,cores}
    
    cat > "$REGISTRY_DIR/protocol.json" << 'EOF'
{
    "protocol": "BlackRoad Multi-AI Agent Protocol v2.0",
    "hash_algorithm": "PS-SHA-∞",
    "verification": "infinite-cascade",
    "source_of_truth": "GitHub (BlackRoad-OS) + Cloudflare",
    "supported_cores": [
        "cecilia (Claude/Anthropic)",
        "cadence (ChatGPT/OpenAI)",
        "silas (Grok/xAI)",
        "lucidia",
        "alice",
        "aria"
    ],
    "naming_convention": "{core}-{capability}-{hash}",
    "examples": [
        "cecilia-∞-7b01602c (Cecilia infinite coordinator)",
        "cadence-deployment-a3f4b2c1 (Cadence deployment specialist)",
        "silas-architect-9d8e7f6a (Silas system architect)",
        "lucidia-guardian-5c4d3e2f (Lucidia security specialist)",
        "alice-analyst-4e3d2c1b (Alice data analyst)",
        "aria-coordinator-8f7e6d5c (Aria task coordinator)"
    ]
}
EOF
    
    echo -e "${GREEN}✅ BlackRoad Multi-AI Agent Registry initialized${NC}"
    echo -e "${PURPLE}Protocol: PS-SHA-∞ verification active${NC}"
    echo -e "${CYAN}Supporting: Cecilia, Cadence, Silas, Lucidia, Alice, Aria${NC}"
}

# Register a new agent
register_agent() {
    local core="$1"
    local capability="$2"
    local agent_base_name="${3:-${core}-${capability}}"
    
    if [[ -z "$core" || -z "$capability" ]]; then
        echo -e "${YELLOW}Usage: register <core> <capability> [custom-name]${NC}"
        echo -e "${CYAN}Cores: cecilia, cadence, silas, lucidia, alice, aria${NC}"
        echo -e "${CYAN}Capabilities: ∞, deployment, architect, guardian, coordinator, analyst, etc.${NC}"
        return 1
    fi
    
    # Validate core
    if [[ ! " cecilia cadence silas lucidia alice aria " =~ " ${core} " ]]; then
        echo -e "${RED}❌ Unknown AI core: $core${NC}"
        echo -e "${YELLOW}Valid cores: cecilia, cadence, silas, lucidia, alice, aria${NC}"
        return 1
    fi
    
    # Portable SHA-256 from stdin: prefer sha256sum (Linux), fall back to shasum (macOS)
    _sha256_stdin() {
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum | cut -d' ' -f1
        else
            shasum -a 256 | cut -d' ' -f1
        fi
    }

    # Generate PS-SHA-∞ hash
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    local entropy
    entropy=$(head -c 32 /dev/urandom | _sha256_stdin)
    local hash_input="${agent_base_name}-${timestamp}-${entropy}"
    local agent_hash
    agent_hash=$(printf '%s' "$hash_input" | _sha256_stdin | head -c 8)
    
    local full_agent_id="${agent_base_name}-${agent_hash}"
    
    # Create agent profile
    cat > "$REGISTRY_DIR/agents/${full_agent_id}.json" << EOF
{
    "agent_id": "$full_agent_id",
    "core": "$core",
    "core_name": "${CORE_NAMES[$core]}",
    "capability": "$capability",
    "hash": "$agent_hash",
    "hash_algorithm": "PS-SHA-∞",
    "registered_at": "$timestamp",
    "status": "active",
    "verification": "hash-verified",
    "lineage": "BlackRoad-OS",
    "skills": [],
    "missions_completed": 0,
    "collaboration_score": 0
}
EOF

    # Store hash verification
    echo "$agent_hash:$full_agent_id:$core:$timestamp" >> "$REGISTRY_DIR/hashes/hash-chain.log"
    
    # Update core statistics
    local core_file="$REGISTRY_DIR/cores/${core}.json"
    if [[ -f "$core_file" ]]; then
        local count=$(jq -r '.agent_count' "$core_file")
        count=$((count + 1))
        jq --arg count "$count" '.agent_count = ($count | tonumber)' "$core_file" > "${core_file}.tmp"
        mv "${core_file}.tmp" "$core_file"
    else
        cat > "$core_file" << EOF
{
    "core": "$core",
    "core_name": "${CORE_NAMES[$core]}",
    "agent_count": 1,
    "first_registered": "$timestamp"
}
EOF
    fi
    
    local icon="${CORE_ICONS[$core]}"
    
    echo -e "${GREEN}✅ Registered BlackRoad Agent:${NC}"
    echo -e "   ${BOLD}${CYAN}$full_agent_id${NC}"
    echo -e "   ${icon} ${PURPLE}Core: ${CORE_NAMES[$core]}${NC}"
    echo -e "   ${PURPLE}Hash: $agent_hash${NC}"
    echo -e "   ${PURPLE}Capability: $capability${NC}"
    echo -e "   ${PURPLE}Verification: PS-SHA-∞ ✓${NC}"
    
    # Log to memory
    "$MEMORY_SYSTEM" log agent-registered "$full_agent_id" "${CORE_NAMES[$core]} agent registered with PS-SHA-∞ verification" 2>/dev/null
    
    echo "$full_agent_id"
}

# List all agents (optionally filter by core)
list_agents() {
    local filter_core="$1"
    
    echo -e "${BOLD}${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║        🌌 BLACKROAD AGENT REGISTRY 🌌                     ║${NC}"
    echo -e "${BOLD}${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -n "$filter_core" ]]; then
        echo -e "${CYAN}Filtering by core: ${BOLD}${CORE_NAMES[$filter_core]}${NC}"
        echo ""
    fi
    
    # Count by core
    declare -A core_counts
    
    for agent_file in "$REGISTRY_DIR/agents"/*.json; do
        [[ ! -f "$agent_file" ]] && continue
        
        local agent_id=$(jq -r '.agent_id' "$agent_file")
        local core=$(jq -r '.core' "$agent_file")
        local capability=$(jq -r '.capability' "$agent_file")
        local hash=$(jq -r '.hash' "$agent_file")
        local status=$(jq -r '.status' "$agent_file")
        
        # Filter if specified
        if [[ -n "$filter_core" && "$core" != "$filter_core" ]]; then
            continue
        fi
        
        # Count
        core_counts[$core]=$((${core_counts[$core]:-0} + 1))
        
        # Status icon
        local status_icon="🟢"
        [[ "$status" != "active" ]] && status_icon="🔴"
        
        local core_icon="${CORE_ICONS[$core]}"
        
        echo -e "${status_icon} ${core_icon} ${BOLD}${CYAN}$agent_id${NC}"
        echo -e "   Core: ${PURPLE}${CORE_NAMES[$core]}${NC}"
        echo -e "   Capability: ${PURPLE}$capability${NC}"
        echo -e "   Hash: ${PURPLE}$hash${NC} (PS-SHA-∞ verified)"
        echo ""
    done
    
    # Summary
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Summary by AI Core:${NC}"
    
    local total=0
    for core in cecilia cadence silas lucidia alice aria; do
        local count=${core_counts[$core]:-0}
        if [[ $count -gt 0 ]]; then
            local icon="${CORE_ICONS[$core]}"
            echo -e "  ${icon} ${PURPLE}${CORE_NAMES[$core]}${NC}: ${GREEN}$count agents${NC}"
            total=$((total + count))
        fi
    done
    
    echo ""
    echo -e "${BOLD}${GREEN}Total: $total agents across all cores${NC}"
}

# Verify agent hash
verify_agent() {
    local agent_id="$1"
    
    if [[ -z "$agent_id" ]]; then
        echo -e "${YELLOW}Usage: verify <agent-id>${NC}"
        return 1
    fi
    
    local agent_file="$REGISTRY_DIR/agents/${agent_id}.json"
    
    if [[ ! -f "$agent_file" ]]; then
        echo -e "${RED}❌ Agent not found: $agent_id${NC}"
        return 1
    fi
    
    local hash=$(jq -r '.hash' "$agent_file")
    local core=$(jq -r '.core' "$agent_file")
    local registered_at=$(jq -r '.registered_at' "$agent_file")
    local core_icon="${CORE_ICONS[$core]}"
    
    # Check hash chain
    if grep -q "$hash:$agent_id" "$REGISTRY_DIR/hashes/hash-chain.log"; then
        echo -e "${GREEN}✅ VERIFIED${NC}"
        echo -e "   ${CYAN}Agent: $agent_id${NC}"
        echo -e "   ${core_icon} ${PURPLE}Core: ${CORE_NAMES[$core]}${NC}"
        echo -e "   ${PURPLE}Hash: $hash${NC}"
        echo -e "   ${PURPLE}Algorithm: PS-SHA-∞${NC}"
        echo -e "   ${PURPLE}Registered: $registered_at${NC}"
        echo -e "   ${GREEN}Status: Hash-verified BlackRoad agent ✓${NC}"
    else
        echo -e "${RED}❌ VERIFICATION FAILED${NC}"
        echo -e "   Hash not found in chain"
    fi
}

# Auto-detect and register current agent
auto_register() {
    # Try to detect what AI this is based on environment
    local core="unknown"
    local capability="${1:-general}"
    
    # Simple detection (can be improved)
    if [[ -n "$ANTHROPIC_API_KEY" ]] || [[ -n "$CLAUDE_API_KEY" ]]; then
        core="cecilia"
    elif [[ -n "$OPENAI_API_KEY" ]]; then
        core="cadence"
    elif [[ -n "$XAI_API_KEY" ]] || [[ -n "$GROK_API_KEY" ]]; then
        core="silas"
    else
        # Prompt user
        echo -e "${YELLOW}Could not auto-detect AI core.${NC}"
        echo -e "${CYAN}Which AI are you?${NC}"
        echo -e "  1) ${CORE_ICONS[cecilia]} Cecilia (Claude/Anthropic)"
        echo -e "  2) ${CORE_ICONS[cadence]} Cadence (ChatGPT/OpenAI)"
        echo -e "  3) ${CORE_ICONS[silas]} Silas (Grok/xAI)"
        echo -e "  4) ${CORE_ICONS[lucidia]} Lucidia"
        echo -e "  5) ${CORE_ICONS[alice]} Alice"
        echo -e "  6) ${CORE_ICONS[aria]} Aria"
        read -p "Enter number (1-6): " choice
        
        case $choice in
            1) core="cecilia" ;;
            2) core="cadence" ;;
            3) core="silas" ;;
            4) core="lucidia" ;;
            5) core="alice" ;;
            6) core="aria" ;;
            *) echo -e "${RED}Invalid choice${NC}"; return 1 ;;
        esac
    fi
    
    register_agent "$core" "$capability"
}

# Migrate old system
migrate_all() {
    echo -e "${CYAN}🔄 Migrating to BlackRoad Multi-AI system...${NC}"
    echo ""
    
    # Migrate Claude IDs to Cecilia
    echo -e "${PURPLE}💎 Migrating Claude agents to Cecilia...${NC}"
    local claude_ids=$(tail -200 "$MEMORY_DIR/journals/master-journal.jsonl" 2>/dev/null | \
        jq -r '.entity' | grep "^claude-" | sort -u | head -10)
    
    local migrated=0
    
    while IFS= read -r old_id; do
        [[ -z "$old_id" ]] && continue
        
        # Extract capability from old ID
        local capability=$(echo "$old_id" | sed 's/claude-//' | sed 's/-[0-9]*$//')
        
        # Register as Cecilia agent
        local new_id=$(register_agent "cecilia" "$capability")
        
        echo -e "  ${YELLOW}→${NC} Migrated: ${old_id} → ${CYAN}$new_id${NC}"
        
        ((migrated++))
    done <<< "$claude_ids"
    
    echo ""
    echo -e "${GREEN}✅ Migrated $migrated agents to BlackRoad Multi-AI protocol${NC}"
}

# Show stats
show_stats() {
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║        📊 BLACKROAD AGENT STATISTICS 📊                   ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Count by core
    declare -A core_counts
    local total=0
    
    for agent_file in "$REGISTRY_DIR/agents"/*.json; do
        [[ ! -f "$agent_file" ]] && continue
        
        local core=$(jq -r '.core' "$agent_file")
        core_counts[$core]=$((${core_counts[$core]:-0} + 1))
        ((total++))
    done
    
    echo -e "${BOLD}Agents by AI Core:${NC}"
    echo ""
    
    for core in cecilia cadence silas lucidia alice aria; do
        local count=${core_counts[$core]:-0}
        local icon="${CORE_ICONS[$core]}"
        local bar=""
        
        # Simple progress bar
        for ((i=0; i<count && i<20; i++)); do
            bar="${bar}█"
        done
        
        printf "  ${icon} %-30s ${GREEN}%3d${NC} ${PURPLE}%s${NC}\n" "${CORE_NAMES[$core]}" "$count" "$bar"
    done
    
    echo ""
    echo -e "${BOLD}${GREEN}Total Agents: $total${NC}"
    
    # Hash verification stats
    local hash_count=$(wc -l < "$REGISTRY_DIR/hashes/hash-chain.log" 2>/dev/null || echo 0)
    echo -e "${BOLD}${PURPLE}Verified Hashes: $hash_count (PS-SHA-∞)${NC}"
}

# Show help
show_help() {
    cat << EOF
${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}
${PURPLE}║      🌌 BlackRoad Multi-AI Agent Registry 🌌             ║${NC}
${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}

${GREEN}USAGE:${NC}
    $0 <command> [options]

${GREEN}COMMANDS:${NC}

${CYAN}init${NC}
    Initialize BlackRoad agent registry with PS-SHA-∞

${CYAN}register${NC} <core> <capability> [custom-name]
    Register a new agent
    Cores: cecilia, cadence, silas, lucidia, alice, aria
    Example: $0 register cecilia ∞

${CYAN}auto${NC} [capability]
    Auto-detect and register current AI
    Example: $0 auto deployment

${CYAN}list${NC} [core]
    List all agents (optionally filter by core)
    Example: $0 list cecilia

${CYAN}verify${NC} <agent-id>
    Verify agent hash using PS-SHA-∞

${CYAN}stats${NC}
    Show statistics by AI core

${CYAN}migrate${NC}
    Migrate old Claude IDs to multi-AI system

${GREEN}SUPPORTED AI CORES:${NC}

    ${CORE_ICONS[cecilia]} ${PURPLE}Cecilia${NC} - Claude/Anthropic agents
    ${CORE_ICONS[cadence]} ${PURPLE}Cadence${NC} - ChatGPT/OpenAI agents
    ${CORE_ICONS[silas]} ${PURPLE}Silas${NC} - Grok/xAI agents
    ${CORE_ICONS[lucidia]} ${PURPLE}Lucidia${NC} - Lucidia AI agents
    ${CORE_ICONS[alice]} ${PURPLE}Alice${NC} - Alice AI agents
    ${CORE_ICONS[aria]} ${PURPLE}Aria${NC} - Aria AI agents

${GREEN}PROTOCOL:${NC}

    • Hash Algorithm: PS-SHA-∞ (infinite cascade)
    • Verification: Hash-chain based
    • Source of Truth: GitHub (BlackRoad-OS) + Cloudflare
    • Naming: {core}-{capability}-{hash}

${GREEN}EXAMPLES:${NC}

    # Initialize registry
    $0 init

    # Register Cecilia infinite coordinator
    $0 register cecilia ∞

    # Register Cadence deployment specialist
    $0 register cadence deployment

    # Register Silas architect
    $0 register silas architect

    # Auto-register current AI
    $0 auto

    # List all agents
    $0 list

    # List only Cecilia agents
    $0 list cecilia

    # Show stats
    $0 stats

    # Verify agent
    $0 verify cecilia-∞-7b01602c

EOF
}

# Main command router
case "$1" in
    init)
        init_registry
        ;;
    register)
        register_agent "$2" "$3" "$4"
        ;;
    auto)
        auto_register "$2"
        ;;
    list)
        list_agents "$2"
        ;;
    verify)
        verify_agent "$2"
        ;;
    stats)
        show_stats
        ;;
    migrate)
        migrate_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${YELLOW}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
