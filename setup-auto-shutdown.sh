#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Contoso Creative Writer - Auto-Shutdown Setup
# Provisions Azure Automation to stop Container Apps at 22:00 UTC daily.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTOMATION_ACCOUNT_NAME="auto-shutdown-contoso-writer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cleanup temp file on exit
trap 'rm -f /tmp/stop-container-apps.ps1' EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Contoso Creative Writer - Auto-Shutdown Setup  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() {
    local num="$1"
    local total="$2"
    local msg="$3"
    echo -e "${BLUE}[$num/$total] $msg${NC}"
}

success() {
    echo -e "${GREEN}  OK: $1${NC}"
}

fail() {
    echo -e "${RED}  ERROR: $1${NC}"
    exit 1
}

# ---------------------------------------------------------------------------
# load_env
# ---------------------------------------------------------------------------

load_env() {
    local primary_env="$SCRIPT_DIR/src/api/.env"
    local fallback_env="$SCRIPT_DIR/.azure/contoso-writer/.env"
    local env_file=""

    if [[ -f "$primary_env" ]]; then
        env_file="$primary_env"
        echo -e "${BLUE}Loading env from:${NC} $env_file"
    elif [[ -f "$fallback_env" ]]; then
        env_file="$fallback_env"
        echo -e "${YELLOW}Primary .env not found, using fallback:${NC} $env_file"
    else
        fail "No .env file found at $primary_env or $fallback_env"
    fi

    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a

    AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
    AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
    AZURE_LOCATION="${AZURE_LOCATION:-}"
    API_SERVICE_ACA_NAME="${API_SERVICE_ACA_NAME:-}"
    WEB_SERVICE_ACA_NAME="${WEB_SERVICE_ACA_NAME:-}"

    local missing=()
    [[ -z "$AZURE_RESOURCE_GROUP"   ]] && missing+=("AZURE_RESOURCE_GROUP")
    [[ -z "$AZURE_SUBSCRIPTION_ID"  ]] && missing+=("AZURE_SUBSCRIPTION_ID")
    [[ -z "$AZURE_LOCATION"         ]] && missing+=("AZURE_LOCATION")
    [[ -z "$API_SERVICE_ACA_NAME"   ]] && missing+=("API_SERVICE_ACA_NAME")
    [[ -z "$WEB_SERVICE_ACA_NAME"   ]] && missing+=("WEB_SERVICE_ACA_NAME")

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing required env vars: ${missing[*]}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

print_header

TOTAL_STEPS=11

# [0/11] Preflight
echo -e "${BLUE}[0/$TOTAL_STEPS] Preflight checks...${NC}"

if ! command -v az &>/dev/null; then
    fail "Azure CLI (az) is not installed or not in PATH"
fi
success "az CLI found"

if ! az account show &>/dev/null; then
    fail "Not logged in to Azure. Run: az login"
fi
success "Azure login verified"

load_env
success "Env vars loaded"

echo ""
echo -e "  Resource Group:  ${YELLOW}$AZURE_RESOURCE_GROUP${NC}"
echo -e "  Subscription:    ${YELLOW}$AZURE_SUBSCRIPTION_ID${NC}"
echo -e "  Location:        ${YELLOW}$AZURE_LOCATION${NC}"
echo -e "  API App:         ${YELLOW}$API_SERVICE_ACA_NAME${NC}"
echo -e "  Web App:         ${YELLOW}$WEB_SERVICE_ACA_NAME${NC}"
echo -e "  Automation Acct: ${YELLOW}$AUTOMATION_ACCOUNT_NAME${NC}"
echo ""

# [1/11] Create Automation Account
step 1 "$TOTAL_STEPS" "Creating Automation Account..."
az automation account create \
    --name "$AUTOMATION_ACCOUNT_NAME" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    --sku Free
success "Automation account '$AUTOMATION_ACCOUNT_NAME' created"

# Wait for account to fully propagate across Azure services
echo -e "${YELLOW}  Waiting 30s for account to propagate across Azure services...${NC}"
sleep 30

# [2/11] Enable system-assigned managed identity
step 2 "$TOTAL_STEPS" "Enabling system-assigned managed identity..."
az rest --method PATCH \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME?api-version=2023-11-01" \
    --body '{"identity":{"type":"SystemAssigned"}}'
success "Managed identity enabled"

# [3/11] Get principal ID
step 3 "$TOTAL_STEPS" "Retrieving managed identity principal ID..."
IDENTITY_PRINCIPAL_ID=$(az rest --method GET \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME?api-version=2023-11-01" \
    --query "identity.principalId" -o tsv)

if [[ -z "$IDENTITY_PRINCIPAL_ID" ]]; then
    fail "Could not retrieve principalId for managed identity"
fi
success "Principal ID: $IDENTITY_PRINCIPAL_ID"

# [4/11] Assign Contributor role on resource group
step 4 "$TOTAL_STEPS" "Assigning Contributor role on resource group..."
az role assignment create \
    --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Contributor" \
    --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"
success "Contributor role assigned"

# [5/11] Write PowerShell runbook to temp file
step 5 "$TOTAL_STEPS" "Generating PowerShell runbook content..."
cat > /tmp/stop-container-apps.ps1 <<'PSEOF'
try {
    Connect-AzAccount -Identity
    $resourceGroup = "__RESOURCE_GROUP__"
    $subscriptionId = "__SUBSCRIPTION_ID__"
    Set-AzContext -SubscriptionId $subscriptionId
    $containerApps = @("__API_APP__", "__WEB_APP__")
    foreach ($app in $containerApps) {
        Write-Output "Stopping Container App: $app"
        $result = Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.App/containerApps/$app/stop?api-version=2023-05-01" -Method POST
        if ($result.StatusCode -eq 200 -or $result.StatusCode -eq 202) {
            Write-Output "Successfully stopped $app"
        } else {
            Write-Output "Warning: Status $($result.StatusCode) for $app"
        }
    }
    Write-Output "Shutdown complete at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
}
catch {
    Write-Error "Failed: $_"
    throw
}
PSEOF

# Substitute actual values
sed -i \
    -e "s|__RESOURCE_GROUP__|$AZURE_RESOURCE_GROUP|g" \
    -e "s|__SUBSCRIPTION_ID__|$AZURE_SUBSCRIPTION_ID|g" \
    -e "s|__API_APP__|$API_SERVICE_ACA_NAME|g" \
    -e "s|__WEB_APP__|$WEB_SERVICE_ACA_NAME|g" \
    /tmp/stop-container-apps.ps1
success "Runbook script written to /tmp/stop-container-apps.ps1"

# [6/11] Create runbook (with retry for propagation delays)
step 6 "$TOTAL_STEPS" "Creating PowerShell runbook..."
for attempt in $(seq 1 6); do
    if az rest --method PUT \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/runbooks/StopContainerApps?api-version=2023-11-01" \
        --body '{
            "location": "'"$AZURE_LOCATION"'",
            "properties": {
                "runbookType": "PowerShell",
                "description": "Stops Container Apps at 22:00 UTC daily",
                "draft": {}
            }
        }' 2>&1; then
        break
    fi
    if [[ $attempt -eq 6 ]]; then
        fail "Could not create runbook after 6 attempts. Azure may need more time to propagate."
    fi
    echo -e "${YELLOW}  Attempt $attempt/6 failed, waiting 15s before retry...${NC}"
    sleep 15
done
success "Runbook 'StopContainerApps' created"

# [7/11] Upload runbook content
step 7 "$TOTAL_STEPS" "Uploading runbook content..."
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/runbooks/StopContainerApps/draft/content?api-version=2023-11-01" \
    --headers "Content-Type=text/powershell" \
    --body @/tmp/stop-container-apps.ps1
success "Runbook content uploaded"

# [8/11] Publish runbook
step 8 "$TOTAL_STEPS" "Publishing runbook..."
az rest --method POST \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/runbooks/StopContainerApps/publish?api-version=2023-11-01"
success "Runbook published"

# [9/11] Create schedule
step 9 "$TOTAL_STEPS" "Creating daily schedule (22:00 UTC)..."
START_TIME=$(date -u -d "+1 day" +"%Y-%m-%dT22:00:00+00:00")
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/schedules/DailyShutdown2200UTC?api-version=2023-11-01" \
    --body '{
        "properties": {
            "description": "Daily shutdown at 22:00 UTC",
            "startTime": "'"$START_TIME"'",
            "frequency": "Day",
            "interval": 1,
            "timeZone": "UTC"
        }
    }'
success "Schedule 'DailyShutdown2200UTC' created (starts $START_TIME)"

# [10/11] Link schedule to runbook
step 10 "$TOTAL_STEPS" "Linking schedule to runbook..."
JOB_SCHEDULE_ID=$(cat /proc/sys/kernel/random/uuid)
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/jobSchedules/$JOB_SCHEDULE_ID?api-version=2023-11-01" \
    --body "{\"properties\":{\"schedule\":{\"name\":\"DailyShutdown2200UTC\"},\"runbook\":{\"name\":\"StopContainerApps\"}}}"
success "Schedule linked to runbook (jobScheduleId: $JOB_SCHEDULE_ID)"

# [11/11] Done
step 11 "$TOTAL_STEPS" "Setup complete."

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Auto-Shutdown Setup Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}Automation Account:${NC}  $AUTOMATION_ACCOUNT_NAME"
echo -e "  ${BLUE}Resource Group:${NC}      $AZURE_RESOURCE_GROUP"
echo -e "  ${BLUE}Schedule:${NC}            Daily at 22:00 UTC"
echo -e "  ${BLUE}Stops:${NC}               $API_SERVICE_ACA_NAME"
echo -e "               ${BLUE}             $WEB_SERVICE_ACA_NAME${NC}"
echo ""
echo -e "  ${YELLOW}To verify the schedule:${NC}"
echo -e "    az automation schedule list \\"
echo -e "      --automation-account-name \"$AUTOMATION_ACCOUNT_NAME\" \\"
echo -e "      --resource-group \"$AZURE_RESOURCE_GROUP\" \\"
echo -e "      --output table"
echo ""
echo -e "  ${YELLOW}To remove the automation entirely:${NC}"
echo -e "    az automation account delete \\"
echo -e "      --name \"$AUTOMATION_ACCOUNT_NAME\" \\"
echo -e "      --resource-group \"$AZURE_RESOURCE_GROUP\" \\"
echo -e "      --yes"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
