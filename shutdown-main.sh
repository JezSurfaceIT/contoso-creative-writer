#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Contoso Creative Writer - Shutdown Script
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Constants
API_PORT=48000
WEB_PORT=45173
PID_DIR="$SCRIPT_DIR/.pids"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Flags
LOCAL_ONLY=false
AZURE_ONLY=false
CLEAN_LOGS=false
NO_WAIT=false

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local-only)
                LOCAL_ONLY=true
                shift
                ;;
            --azure-only)
                AZURE_ONLY=true
                shift
                ;;
            --clean-logs)
                CLEAN_LOGS=true
                shift
                ;;
            --no-wait)
                NO_WAIT=true
                shift
                ;;
            *)
                echo -e "${YELLOW}Warning: Unknown argument '$1' (ignored)${RESET}"
                shift
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# print_header
# ---------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║   Contoso Creative Writer - Shutdown    ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# load_env
# ---------------------------------------------------------------------------
load_env() {
    local env_file=""

    if [[ -f "$SCRIPT_DIR/src/api/.env" ]]; then
        env_file="$SCRIPT_DIR/src/api/.env"
    elif [[ -f "$SCRIPT_DIR/.azure/contoso-writer/.env" ]]; then
        env_file="$SCRIPT_DIR/.azure/contoso-writer/.env"
    fi

    if [[ -n "$env_file" ]]; then
        echo -e "${BLUE}Loading environment from:${RESET} $env_file"
        # shellcheck disable=SC1090
        set -a
        source "$env_file"
        set +a
        AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
    else
        echo -e "${YELLOW}No .env file found; proceeding without environment variables.${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# kill_by_pid_file <pid_file> <label>
# ---------------------------------------------------------------------------
kill_by_pid_file() {
    local pid_file="$1"
    local label="$2"

    if [[ ! -f "$pid_file" ]]; then
        echo -e "  ${YELLOW}No PID file for ${label} (already stopped?)${RESET}"
        return 0
    fi

    local pid
    pid="$(cat "$pid_file")"

    if [[ -z "$pid" ]]; then
        echo -e "  ${YELLOW}PID file for ${label} is empty; removing.${RESET}"
        rm -f "$pid_file"
        return 0
    fi

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "  ${BLUE}Stopping ${label} (PID ${pid})...${RESET}"
        kill "$pid" || true
        sleep 3

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${YELLOW}${label} still alive; sending SIGKILL...${RESET}"
            kill -9 "$pid" || true
        fi

        echo -e "  ${GREEN}${label} stopped.${RESET}"
    else
        echo -e "  ${YELLOW}${label} (PID ${pid}) is not running.${RESET}"
    fi

    rm -f "$pid_file"
}

# ---------------------------------------------------------------------------
# kill_by_port <port> <label>
# ---------------------------------------------------------------------------
kill_by_port() {
    local port="$1"
    local label="$2"

    # Try lsof first
    local pids
    pids="$(lsof -ti:"$port" 2>/dev/null || true)"

    if [[ -n "$pids" ]]; then
        echo -e "  ${BLUE}Killing ${label} processes on port ${port}...${RESET}"
        # shellcheck disable=SC2086
        kill $pids 2>/dev/null || true
        sleep 1
        pids="$(lsof -ti:"$port" 2>/dev/null || true)"
        if [[ -n "$pids" ]]; then
            # shellcheck disable=SC2086
            kill -9 $pids 2>/dev/null || true
        fi
        echo -e "  ${GREEN}Port ${port} cleared.${RESET}"
        return 0
    fi

    # Fallback: fuser
    if command -v fuser &>/dev/null; then
        if fuser -k "${port}/tcp" 2>/dev/null; then
            echo -e "  ${GREEN}Port ${port} cleared via fuser.${RESET}"
        else
            echo -e "  ${CYAN}No process found on port ${port} (${label}).${RESET}"
        fi
    else
        echo -e "  ${CYAN}No process found on port ${port} (${label}).${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# stop_local
# ---------------------------------------------------------------------------
stop_local() {
    echo -e "${BOLD}Stopping local processes...${RESET}"

    kill_by_pid_file "$PID_DIR/api.pid" "API server"
    kill_by_pid_file "$PID_DIR/web.pid" "Web server"

    echo -e "  ${BLUE}Safety net: freeing ports...${RESET}"
    kill_by_port "$API_PORT" "API"
    kill_by_port "$WEB_PORT" "Web"

    # Verify ports are free
    local all_free=true
    for port in "$API_PORT" "$WEB_PORT"; do
        if lsof -ti:"$port" &>/dev/null 2>&1; then
            echo -e "  ${RED}Warning: port ${port} still in use!${RESET}"
            all_free=false
        fi
    done

    if $all_free; then
        echo -e "  ${GREEN}All local ports are free.${RESET}"
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# stop_azure
# ---------------------------------------------------------------------------
stop_azure() {
    echo -e "${BOLD}Stopping Azure Container Apps...${RESET}"

    if ! command -v az &>/dev/null; then
        echo -e "  ${YELLOW}Azure CLI (az) not found; skipping Azure shutdown.${RESET}"
        echo ""
        return 0
    fi

    local rg="${AZURE_RESOURCE_GROUP:-}"
    if [[ -z "$rg" ]]; then
        echo -e "  ${YELLOW}AZURE_RESOURCE_GROUP not set; skipping Azure shutdown.${RESET}"
        echo ""
        return 0
    fi

    local no_wait_flag=""
    if $NO_WAIT; then
        no_wait_flag="--no-wait"
    fi

    for var_name in API_SERVICE_ACA_NAME WEB_SERVICE_ACA_NAME; do
        local name="${!var_name:-}"
        if [[ -z "$name" ]]; then
            echo -e "  ${YELLOW}${var_name} not set; skipping.${RESET}"
            continue
        fi

        echo -e "  ${BLUE}Stopping container app '${name}' in resource group '${rg}'...${RESET}"
        if az rest --method POST \
                --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${rg}/providers/Microsoft.App/containerApps/${name}/stop?api-version=2023-05-01" 2>&1; then
            echo -e "  ${GREEN}'${name}' stop command issued.${RESET}"
        else
            echo -e "  ${RED}Failed to stop '${name}' (continuing).${RESET}"
        fi
    done

    echo ""
}

# ---------------------------------------------------------------------------
# cleanup
# ---------------------------------------------------------------------------
cleanup() {
    echo -e "${BOLD}Cleaning up...${RESET}"

    if [[ -d "$PID_DIR" ]]; then
        rm -f "$PID_DIR"/*.pid 2>/dev/null || true
        echo -e "  ${GREEN}PID files removed.${RESET}"
    fi

    if $CLEAN_LOGS; then
        if [[ -d "$LOG_DIR" ]]; then
            rm -f "$LOG_DIR"/*.log 2>/dev/null || true
            echo -e "  ${GREEN}Log files removed.${RESET}"
        else
            echo -e "  ${YELLOW}Log directory not found; nothing to clean.${RESET}"
        fi
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# print_summary
# ---------------------------------------------------------------------------
print_summary() {
    echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║             Shutdown Complete           ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
    echo ""

    if ! $AZURE_ONLY; then
        echo -e "  ${GREEN}Local processes:${RESET}  stopped"
    fi

    if ! $LOCAL_ONLY; then
        echo -e "  ${GREEN}Azure services:${RESET}   stop command sent"
    fi

    if $CLEAN_LOGS; then
        echo -e "  ${GREEN}Log files:${RESET}        removed"
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
parse_args "$@"
print_header
load_env

if ! $AZURE_ONLY; then
    stop_local
fi

if ! $LOCAL_ONLY; then
    stop_azure
fi

cleanup
print_summary
