#!/bin/bash
# BlackRoad Multi-AI System — Integration Test Suite
# Tests all core scripts end-to-end in an isolated environment.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
export BLACKROAD_MEMORY_DIR="$TEST_HOME/.blackroad/memory"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────

pass() {
    echo -e "  ${GREEN}✅ PASS${NC}: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}❌ FAIL${NC}: $1"
    FAIL=$((FAIL + 1))
    ERRORS+=("$1")
}

assert_exit_ok() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label (exit code non-zero)"
    fi
}

assert_output_contains() {
    local label="$1"
    local pattern="$2"
    shift 2
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -q "$pattern"; then
        pass "$label"
    else
        fail "$label (pattern '${pattern}' not found in output)"
        echo "    Output was: $output" >&2
    fi
}

assert_file_exists() {
    local label="$1"
    local file="$2"
    if [[ -f "$file" ]]; then
        pass "$label"
    else
        fail "$label (file not found: $file)"
    fi
}

assert_dir_exists() {
    local label="$1"
    local dir="$2"
    if [[ -d "$dir" ]]; then
        pass "$label"
    else
        fail "$label (directory not found: $dir)"
    fi
}

# ── test sections ─────────────────────────────────────────────────────────────

test_memory_system() {
    echo -e "\n${CYAN}${BOLD}── memory-system.sh ──────────────────────────────────────────${NC}"

    bash "$REPO_DIR/memory-system.sh" log test-action test-entity "hello journal" 2>&1

    assert_file_exists "journal file created" \
        "$HOME/.blackroad/memory/journals/master-journal.jsonl"

    assert_output_contains "recent shows logged entry" \
        "test-action" \
        bash "$REPO_DIR/memory-system.sh" recent 5

    assert_output_contains "stats shows entry count" \
        "Total entries" \
        bash "$REPO_DIR/memory-system.sh" stats

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/memory-system.sh" help
}

test_agent_registry() {
    echo -e "\n${CYAN}${BOLD}── blackroad-agent-registry.sh ───────────────────────────────${NC}"

    assert_output_contains "init creates registry" \
        "initialized" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" init

    assert_dir_exists "agents directory created" \
        "$HOME/.blackroad/memory/agent-registry/agents"

    assert_dir_exists "hashes directory created" \
        "$HOME/.blackroad/memory/agent-registry/hashes"

    # Register one agent of each supported core
    for core in cecilia cadence silas lucidia alice aria; do
        assert_output_contains "register $core agent" \
            "Registered BlackRoad Agent" \
            bash "$REPO_DIR/blackroad-agent-registry.sh" register "$core" developer
    done

    assert_output_contains "list shows registered agents" \
        "cecilia" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" list

    assert_output_contains "stats shows total agents" \
        "Total Agents:" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" stats

    assert_output_contains "stats shows verified hashes" \
        "Verified Hashes:" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" stats

    # Capture agent ID for verify test
    local agent_id
    agent_id=$(bash "$REPO_DIR/blackroad-agent-registry.sh" register cecilia coordinator 2>/dev/null | tail -1)
    assert_output_contains "verify confirms registered agent" \
        "VERIFIED" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" verify "$agent_id"

    assert_output_contains "unknown core is rejected" \
        "Unknown AI core" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" register unknowncore dev 2>&1 || true

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/blackroad-agent-registry.sh" help
}

test_task_marketplace() {
    echo -e "\n${CYAN}${BOLD}── memory-task-marketplace.sh ────────────────────────────────${NC}"

    assert_output_contains "init creates marketplace" \
        "initialized" \
        bash "$REPO_DIR/memory-task-marketplace.sh" init

    assert_dir_exists "available tasks dir" \
        "$HOME/.blackroad/memory/tasks/available"

    assert_dir_exists "claimed tasks dir" \
        "$HOME/.blackroad/memory/tasks/claimed"

    assert_dir_exists "completed tasks dir" \
        "$HOME/.blackroad/memory/tasks/completed"

    assert_output_contains "post creates task" \
        "Task posted" \
        bash "$REPO_DIR/memory-task-marketplace.sh" post task-001 "Build API" "REST API" high backend python

    assert_file_exists "task JSON file created" \
        "$HOME/.blackroad/memory/tasks/available/task-001.json"

    assert_output_contains "list shows posted task" \
        "task-001" \
        bash "$REPO_DIR/memory-task-marketplace.sh" list

    assert_output_contains "claim moves task to claimed" \
        "Task claimed" \
        bash "$REPO_DIR/memory-task-marketplace.sh" claim task-001 test-agent 60

    assert_file_exists "task JSON in claimed dir" \
        "$HOME/.blackroad/memory/tasks/claimed/task-001.json"

    assert_output_contains "complete moves task to done" \
        "Task completed" \
        bash "$REPO_DIR/memory-task-marketplace.sh" complete task-001 "Done!"

    assert_file_exists "task JSON in completed dir" \
        "$HOME/.blackroad/memory/tasks/completed/task-001.json"

    # Post and release a second task
    bash "$REPO_DIR/memory-task-marketplace.sh" post task-002 "Other task" "desc" medium general any >/dev/null 2>&1
    bash "$REPO_DIR/memory-task-marketplace.sh" claim task-002 test-agent 30 >/dev/null 2>&1
    assert_output_contains "release returns task to available" \
        "Task released" \
        bash "$REPO_DIR/memory-task-marketplace.sh" release task-002 "Blocked"

    assert_output_contains "stats shows completion rate" \
        "Completion Rate" \
        bash "$REPO_DIR/memory-task-marketplace.sh" stats

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/memory-task-marketplace.sh" help
}

test_til_broadcast() {
    echo -e "\n${CYAN}${BOLD}── memory-til-broadcast.sh ───────────────────────────────────${NC}"

    assert_output_contains "init creates TIL system" \
        "initialized" \
        bash "$REPO_DIR/memory-til-broadcast.sh" init

    assert_output_contains "broadcast posts TIL" \
        "TIL broadcast" \
        bash "$REPO_DIR/memory-til-broadcast.sh" broadcast discovery "Bash is portable" test-agent

    assert_output_contains "list shows broadcast" \
        "Bash is portable" \
        bash "$REPO_DIR/memory-til-broadcast.sh" list

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/memory-til-broadcast.sh" help
}

test_traffic_light() {
    echo -e "\n${CYAN}${BOLD}── blackroad-traffic-light.sh ────────────────────────────────${NC}"

    assert_output_contains "init creates traffic light system" \
        "initialized" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" init

    assert_output_contains "set green light" \
        "GREEN LIGHT" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" set pr-100 green "Tests pass" ci-bot

    assert_output_contains "set yellow light" \
        "YELLOW LIGHT" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" set pr-200 yellow "Needs review" reviewer

    assert_output_contains "set red light" \
        "RED LIGHT" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" set pr-300 red "Security issue" security

    assert_output_contains "check returns correct status" \
        "GREEN LIGHT" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" check pr-100

    assert_output_contains "list shows all lights" \
        "GREEN" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" list

    assert_output_contains "list green filter" \
        "pr-100" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" list green

    assert_output_contains "list red filter" \
        "pr-300" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" list red

    assert_output_contains "auto check pass sets green" \
        "GREEN" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" auto build-main pass

    assert_output_contains "auto check fail sets red" \
        "RED" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" auto build-main fail

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/blackroad-traffic-light.sh" help
}

test_health_monitor() {
    echo -e "\n${CYAN}${BOLD}── blackroad-health-monitor.sh ───────────────────────────────${NC}"

    assert_output_contains "init creates health monitor" \
        "initialized" \
        bash "$REPO_DIR/blackroad-health-monitor.sh" init

    assert_dir_exists "health checks dir" \
        "$HOME/.blackroad/memory/health/checks"

    assert_output_contains "check runs successfully" \
        "AGENT HEALTH CHECK" \
        bash "$REPO_DIR/blackroad-health-monitor.sh" check cecilia-coordinator-test

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/blackroad-health-monitor.sh" help
}

test_leaderboard() {
    echo -e "\n${CYAN}${BOLD}── blackroad-leaderboard.sh ──────────────────────────────────${NC}"

    assert_output_contains "leaderboard shows journal data" \
        "LEADERBOARD" \
        bash "$REPO_DIR/blackroad-leaderboard.sh"

    assert_output_contains "leaderboard shows point system" \
        "Point System" \
        bash "$REPO_DIR/blackroad-leaderboard.sh"
}

test_dependency_notify() {
    echo -e "\n${CYAN}${BOLD}── memory-dependency-notify.sh ───────────────────────────────${NC}"

    assert_output_contains "init creates dependency system" \
        "initialized" \
        bash "$REPO_DIR/memory-dependency-notify.sh" init

    assert_output_contains "subscribe registers dependency" \
        "Subscribed" \
        bash "$REPO_DIR/memory-dependency-notify.sh" subscribe deploy-event test-agent completed

    assert_output_contains "publish notifies subscribers" \
        "Event published" \
        bash "$REPO_DIR/memory-dependency-notify.sh" publish deploy-event completed test-publisher "Deploy done"

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/memory-dependency-notify.sh" help
}

test_skill_matcher() {
    echo -e "\n${CYAN}${BOLD}── blackroad-skill-matcher.sh ────────────────────────────────${NC}"

    assert_output_contains "init creates skill matcher" \
        "initialized" \
        bash "$REPO_DIR/blackroad-skill-matcher.sh" init

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/blackroad-skill-matcher.sh" help
}

test_direct_messaging() {
    echo -e "\n${CYAN}${BOLD}── blackroad-direct-messaging.sh ─────────────────────────────${NC}"

    assert_output_contains "init creates messaging system" \
        "initialized" \
        bash "$REPO_DIR/blackroad-direct-messaging.sh" init

    assert_output_contains "send delivers message" \
        "DM sent to" \
        bash "$REPO_DIR/blackroad-direct-messaging.sh" send agent-alice agent-bob "Hello from Alice!"

    assert_output_contains "read shows messages" \
        "Hello from Alice" \
        bash "$REPO_DIR/blackroad-direct-messaging.sh" read agent-bob

    assert_exit_ok "help exits successfully" \
        bash "$REPO_DIR/blackroad-direct-messaging.sh" help
}

test_achievements() {
    echo -e "\n${CYAN}${BOLD}── blackroad-achievements.sh ─────────────────────────────────${NC}"

    assert_output_contains "shows achievement system" \
        "ACHIEVEMENT" \
        bash "$REPO_DIR/blackroad-achievements.sh"
}

# ── run all tests ──────────────────────────────────────────────────────────────

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       🧪 BlackRoad Multi-AI System — Test Suite              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Test home: ${YELLOW}${TEST_HOME}${NC}"

# Seed the journal so leaderboard tests have data
bash "$REPO_DIR/blackroad-agent-registry.sh" init >/dev/null 2>&1
bash "$REPO_DIR/blackroad-agent-registry.sh" register cecilia coordinator >/dev/null 2>&1
bash "$REPO_DIR/memory-task-marketplace.sh" init >/dev/null 2>&1
bash "$REPO_DIR/memory-task-marketplace.sh" post seed-task "Seed Task" "Seeded" high general any >/dev/null 2>&1
bash "$REPO_DIR/memory-task-marketplace.sh" claim seed-task seed-agent 30 >/dev/null 2>&1
bash "$REPO_DIR/memory-task-marketplace.sh" complete seed-task "Done" >/dev/null 2>&1

test_memory_system
test_agent_registry
test_task_marketplace
test_til_broadcast
test_traffic_light
test_health_monitor
test_leaderboard
test_dependency_notify
test_skill_matcher
test_direct_messaging
test_achievements

# ── summary ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"

if [[ ${FAIL} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Failed tests:${NC}"
    for err in "${ERRORS[@]}"; do
        echo -e "  ${RED}✗${NC} $err"
    done
fi

# Cleanup
rm -rf "$TEST_HOME"

echo ""
if [[ ${FAIL} -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}💥 Some tests failed.${NC}"
    exit 1
fi
