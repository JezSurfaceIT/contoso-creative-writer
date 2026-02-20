#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Contoso Creative Writer - Startup Script
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Constants
API_PORT=48000
WEB_PORT=45173
LOG_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/.pids"
VENV_DIR="$SCRIPT_DIR/.venv"
API_DIR="$SCRIPT_DIR/src/api"
WEB_DIR="$SCRIPT_DIR/src/web"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Status tracking
API_STATUS="unknown"
WEB_STATUS="unknown"
OPENAI_STATUS="unknown"
SEARCH_STATUS="unknown"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Contoso Creative Writer - Start   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
}

print_status() {
    local label="$1"
    local status="$2"
    local color="$NC"

    case "$status" in
        OK|Running|Reachable|Started) color="$GREEN" ;;
        WARN|Skipped|Unknown)         color="$YELLOW" ;;
        FAIL|Unreachable|Error)       color="$RED"    ;;
        *)                            color="$BLUE"   ;;
    esac

    printf "  %-30s [${color}%s${NC}]\n" "$label" "$status"
}

# ---------------------------------------------------------------------------
# load_env
# ---------------------------------------------------------------------------

load_env() {
    local primary_env="$API_DIR/.env"
    local fallback_env="$SCRIPT_DIR/.azure/contoso-writer/.env"
    local env_file=""

    if [[ -f "$primary_env" ]]; then
        env_file="$primary_env"
        echo -e "${BLUE}Loading env from:${NC} $env_file"
    elif [[ -f "$fallback_env" ]]; then
        env_file="$fallback_env"
        echo -e "${YELLOW}Primary .env not found, using fallback:${NC} $env_file"
    else
        echo -e "${YELLOW}Warning: No .env file found. Continuing without env vars.${NC}"
        return 0
    fi

    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a

    # Extract key variables (provide defaults to avoid unbound errors)
    AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
    API_SERVICE_ACA_NAME="${API_SERVICE_ACA_NAME:-}"
    WEB_SERVICE_ACA_NAME="${WEB_SERVICE_ACA_NAME:-}"
    AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT:-}"
    AZURE_SEARCH_ENDPOINT="${AZURE_SEARCH_ENDPOINT:-}"
    AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
}

# ---------------------------------------------------------------------------
# kill_port
# ---------------------------------------------------------------------------

kill_port() {
    local port="$1"
    local pids=""

    # Try lsof first, fall back to fuser
    if command -v lsof &>/dev/null; then
        pids="$(lsof -ti:"$port" 2>/dev/null || true)"
    elif command -v fuser &>/dev/null; then
        pids="$(fuser "$port/tcp" 2>/dev/null | tr ' ' '\n' || true)"
    fi

    if [[ -n "$pids" ]]; then
        echo -e "${YELLOW}Killing existing process(es) on port $port:${NC} $pids"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# ---------------------------------------------------------------------------
# start_api
# ---------------------------------------------------------------------------

start_api() {
    echo -e "${BLUE}Starting API server on port $API_PORT...${NC}"

    if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
        echo -e "${RED}Error: virtualenv not found at $VENV_DIR${NC}"
        API_STATUS="FAIL"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    mkdir -p "$LOG_DIR" "$PID_DIR"

    (
        cd "$API_DIR"
        uvicorn main:app --host 0.0.0.0 --port "$API_PORT" >> "$LOG_DIR/api.log" 2>&1 &
        echo $! > "$PID_DIR/api.pid"
    )

    echo -e "${BLUE}Waiting for API to come up...${NC}"
    sleep 60

    if curl -sf "http://localhost:$API_PORT/" > /dev/null 2>&1; then
        echo -e "${GREEN}API server started successfully.${NC}"
        API_STATUS="Started"
    else
        echo -e "${YELLOW}API health check failed (may still be starting).${NC}"
        API_STATUS="WARN"
    fi
}

# ---------------------------------------------------------------------------
# start_web
# ---------------------------------------------------------------------------

start_web() {
    echo -e "${BLUE}Starting web server on port $WEB_PORT...${NC}"

    mkdir -p "$LOG_DIR" "$PID_DIR"

    (
        cd "$WEB_DIR"
        npx vite --port "$WEB_PORT" >> "$LOG_DIR/web.log" 2>&1 &
        echo $! > "$PID_DIR/web.pid"
    )

    echo -e "${BLUE}Waiting for web server to come up...${NC}"
    sleep 3

    if curl -sf "http://localhost:$WEB_PORT/" > /dev/null 2>&1; then
        echo -e "${GREEN}Web server started successfully.${NC}"
        WEB_STATUS="Started"
    else
        echo -e "${YELLOW}Web health check failed (may still be starting).${NC}"
        WEB_STATUS="WARN"
    fi
}

# ---------------------------------------------------------------------------
# check_azure_container_apps
# ---------------------------------------------------------------------------

check_azure_container_apps() {
    echo ""
    echo -e "${BLUE}Checking Azure Container Apps...${NC}"

    if ! command -v az &>/dev/null; then
        echo -e "${YELLOW}Warning: Azure CLI (az) not found. Skipping container app checks.${NC}"
        return 0
    fi

    if ! az account show &>/dev/null; then
        echo -e "${YELLOW}Warning: Not logged in to Azure. Skipping container app checks.${NC}"
        return 0
    fi

    local rg="${AZURE_RESOURCE_GROUP:-}"
    if [[ -z "$rg" ]]; then
        echo -e "${YELLOW}Warning: AZURE_RESOURCE_GROUP not set. Skipping container app checks.${NC}"
        return 0
    fi

    local apps=()
    [[ -n "${API_SERVICE_ACA_NAME:-}" ]] && apps+=("$API_SERVICE_ACA_NAME")
    [[ -n "${WEB_SERVICE_ACA_NAME:-}" ]] && apps+=("$WEB_SERVICE_ACA_NAME")

    if [[ ${#apps[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No container app names configured. Skipping.${NC}"
        return 0
    fi

    for name in "${apps[@]}"; do
        local running_status
        running_status="$(az containerapp show \
            --name "$name" \
            --resource-group "$rg" \
            --query "properties.runningStatus" \
            -o tsv 2>/dev/null || echo "Unknown")"

        if [[ "$running_status" == "Running" ]]; then
            print_status "ACA: $name" "Running"
        else
            echo -e "${YELLOW}Container app '$name' status: $running_status. Attempting to start...${NC}"
            az rest --method POST \
                --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.App/containerApps/$name/start?api-version=2023-05-01" \
                2>/dev/null || true
            print_status "ACA: $name" "Start requested"
        fi
    done
}

# ---------------------------------------------------------------------------
# check_azure_endpoints
# ---------------------------------------------------------------------------

check_azure_endpoints() {
    echo ""
    echo -e "${BLUE}Checking Azure endpoints...${NC}"

    local openai_ep="${AZURE_OPENAI_ENDPOINT:-}"
    local search_ep="${AZURE_SEARCH_ENDPOINT:-}"

    if [[ -n "$openai_ep" ]]; then
        local http_code
        http_code="$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$openai_ep" 2>/dev/null || echo "000")"
        if [[ "$http_code" != "000" ]]; then
            OPENAI_STATUS="Reachable"
        else
            OPENAI_STATUS="Unreachable"
        fi
        print_status "Azure OpenAI" "$OPENAI_STATUS"
    else
        OPENAI_STATUS="Skipped"
        print_status "Azure OpenAI" "Skipped (not configured)"
    fi

    if [[ -n "$search_ep" ]]; then
        local http_code
        http_code="$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$search_ep" 2>/dev/null || echo "000")"
        if [[ "$http_code" != "000" ]]; then
            SEARCH_STATUS="Reachable"
        else
            SEARCH_STATUS="Unreachable"
        fi
        print_status "Azure AI Search" "$SEARCH_STATUS"
    else
        SEARCH_STATUS="Skipped"
        print_status "Azure AI Search" "Skipped (not configured)"
    fi
}

# ---------------------------------------------------------------------------
# print_summary
# ---------------------------------------------------------------------------

print_summary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_status "API Server (port $API_PORT)" "$API_STATUS"
    print_status "Web Server (port $WEB_PORT)" "$WEB_STATUS"
    print_status "Azure OpenAI Endpoint" "$OPENAI_STATUS"
    print_status "Azure AI Search Endpoint" "$SEARCH_STATUS"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}API:${NC}  http://localhost:$API_PORT"
    echo -e "  ${BLUE}Web:${NC}  http://localhost:$WEB_PORT"
    echo ""
    echo -e "  Logs: ${YELLOW}$LOG_DIR/${NC}"
    echo -e "  PIDs: ${YELLOW}$PID_DIR/${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

print_header
load_env
mkdir -p "$LOG_DIR" "$PID_DIR"
kill_port "$API_PORT"
kill_port "$WEB_PORT"
start_api
start_web
check_azure_container_apps || true
check_azure_endpoints || true
print_summary
