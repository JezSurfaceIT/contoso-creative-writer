# Contoso Creative Writer - Implementation Plan

## Overview

The Contoso Creative Writer is a multi-agent AI application that generates well-researched, product-specific articles. This document provides a structured implementation plan with clear phases, tasks, dependencies, and completion criteria.

**Application Architecture:** FastAPI backend + React frontend with Azure OpenAI orchestrating a research agent, product agent, writer agent, and editor agent.

---

## Phase 1: Prerequisites & Environment Setup

Setup local development environment with required tools and authentication.

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 1.1 | Install Azure Developer CLI (azd) | Visit [aka.ms/install-azd](https://aka.ms/install-azd) and follow instructions for your OS (Windows/Mac/Linux) | None | Completed | Required for infrastructure provisioning |
| 1.2 | Install Python 3.10+ | Download from [python.org](https://www.python.org/downloads/) and verify with `python --version` | None | Completed | Backend requires Python 3.10 or later |
| 1.3 | Install Docker Desktop | Download from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) and start service | None | Completed | Required for container builds and Azure Container Apps |
| 1.4 | Install Node.js 18+ | Download from [nodejs.org](https://nodejs.org/) and verify with `node --version && npm --version` | None | Completed | Frontend build and package management |
| 1.5 | Install Git | Download from [git-scm.com](https://git-scm.com/downloads) and verify with `git --version` | None | Completed | Source code management |
| 1.6 | Authenticate with Azure Developer CLI | Run `azd auth login` and follow device code flow | 1.1 | Completed | Enables infrastructure provisioning |
| 1.7 | Authenticate with Azure CLI | Run `az login --use-device-code` (or `az login` on some systems) | None | Completed | Enables resource queries and management |
| 1.8 | Clone/Initialize Project | Run `azd init -t contoso-creative-writer` to download template into new directory | 1.1, 1.7 | Completed | Sets up git repository and project structure |
| 1.9 | Verify Project Structure | Verify `src/`, `infra/`, `docs/`, and `azure.yaml` exist | 1.8 | Completed | Confirms successful initialization |

**Phase 1 Completion Criteria:**
- `azd --version` returns version >= 1.0
- `python --version` returns 3.10 or higher
- `docker ps` runs without errors
- `npm --version` and `node --version` confirm presence
- `az account show` displays current subscription info

---

## Phase 2: Azure Infrastructure Provisioning

Provision all required Azure resources using Bicep Infrastructure-as-Code.

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 2.1 | Review Supported Regions | Check [model availability](https://learn.microsoft.com/azure/ai-services/openai/concepts/models#standard-deployment-model-availability) for gpt-4o and gpt-4o-mini | None | Completed | Primary: eastus2; Also: swedencentral, northcentralus, francecentral, eastus |
| 2.2 | Provision Infrastructure | From project root, run `azd up` and select region when prompted | 1.6, 1.7 | In Progress | First-time provisioning takes 10-15 minutes |
| 2.3 | Confirm Resource Group Created | Verify resource group via `az group list` or Azure Portal | 2.2 | Pending | Format: `rg-{environment-name}` |
| 2.4 | Verify Azure OpenAI Resources | Check Azure Portal: OpenAI account with `gpt-4o` and `gpt-4o-mini` deployments | 2.2 | Pending | Deployments created automatically by Bicep |
| 2.5 | Verify Azure AI Search Created | Check Portal for AI Search resource with `contoso-products` index | 2.2 | Pending | Created with vector search capability |
| 2.6 | Verify Container Registry Created | Check Portal for Container Registry in resource group | 2.2 | Pending | Used for storing container images |
| 2.7 | Verify Container Apps Created | Check Portal for 2 Container App instances: `api` and `web` | 2.2 | Pending | Both should show as successfully deployed |
| 2.8 | Verify Key Vault Created | Check Portal for Key Vault resource | 2.2 | Pending | Stores sensitive credentials like API keys |
| 2.9 | Verify App Insights & Log Analytics | Confirm both resources exist in resource group | 2.2 | Pending | Used for monitoring and diagnostics |
| 2.10 | Verify Storage Account Created | Check Portal for Storage Account resource | 2.2 | Pending | Supports application storage needs |
| 2.11 | Verify AI Hub & AI Project Created | Confirm both exist in Portal under AI Foundry | 2.2 | Pending | Required for Azure AI Agent Service and evaluations |
| 2.12 | Capture Deployment Endpoints | Note the Container Apps URLs from deployment output | 2.2 | Pending | API and Web service URLs needed for frontend configuration |

**Bicep Infrastructure Details** (`infra/main.bicep`):
- **Allowed Regions:** eastus2, swedencentral, northcentralus, francecentral, eastus
- **Default Region:** eastus2 (recommended)
- **Key Parameters:**
  - `aiSearchIndexName`: contoso-products (default)
  - `openAi_4_DeploymentName`: gpt-4 (default)
  - `openAi_4_eval_DeploymentName`: gpt-4-evals (default)
  - `openAiEmbeddingDeploymentName`: text-embedding-ada-002 (default)

**Phase 2 Completion Criteria:**
- `azd up` completes successfully without errors
- All 11 resource types visible in Azure Portal
- Environment variables populated in `.azure/{env-name}/.env`
- Container Apps services showing "Provisioned" status
- No red error banners in Portal

---

## Phase 3: Post-Provisioning Setup

Execute hooks and configure environment variables automatically via `azd up` post-provisioning phase.

| Task | Description | File | Execution | Status | Notes |
|------|-------------|------|-----------|--------|-------|
| 3.1 | Export Environment Variables | Hook: `infra/hooks/postprovision.sh` | Runs automatically after `azd up` | Pending | Creates `.env` file with all resource values |
| 3.2 | Install Python Dependencies | Hook: `infra/hooks/postprovision.sh` (line: `pip install -r src/api/requirements.txt`) | Automatic | Pending | Installs Prompty, FastAPI, Azure SDK packages |
| 3.3 | Configure Jupyter Kernels | Hook: `infra/hooks/postprovision.sh` | Automatic | Pending | Required for notebook execution in data pipeline |
| 3.4 | Upload Product Data to AI Search | Hook: `infra/hooks/postprovision.sh` (line: `jupyter nbconvert --execute data/create-azure-search.ipynb`) | Automatic | Pending | Populates `contoso-products` index with vector embeddings |
| 3.5 | Verify `.env` File Created | Check for `.env` file in project root | Manual | Pending | Should contain all AZURE_*, BING_*, API_* variables |
| 3.6 | Verify Product Data Indexed | Query AI Search index via Azure Portal or CLI | Manual | Pending | Run: `az search documents list --resource-group {rg} --service-name {search-service} --index-name contoso-products` |

**Environment Variables Set** (from `.env`):
```
AZURE_SUBSCRIPTION_ID=<subscription-id>
AZURE_RESOURCE_GROUP=<resource-group-name>
AZURE_LOCATION=<region>
AZURE_OPENAI_ENDPOINT=<endpoint-url>
AZURE_OPENAI_API_VERSION=2024-08-01-preview
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini
AZURE_OPENAI_4_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_4_EVAL_DEPLOYMENT_NAME=gpt-4-evals
AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME=text-embedding-ada-002
AZURE_SEARCH_ENDPOINT=<search-endpoint>
AZURE_SEARCH_NAME=<search-resource-name>
BING_SEARCH_ENDPOINT=<bing-endpoint>
BING_SEARCH_KEY=<bing-api-key>
AZURE_AI_PROJECT_NAME=<ai-project-name>
APPINSIGHTS_CONNECTIONSTRING=<connection-string>
API_SERVICE_ACA_URI=<api-container-app-url>
WEB_SERVICE_ACA_URI=<web-container-app-url>
```

**Phase 3 Completion Criteria:**
- `.env` file exists with all required variables populated
- No errors in postprovision script output
- `contoso-products` index contains product records with embeddings
- Jupyter kernel successfully configured and tested

---

## Phase 4: Local Development Environment

Setup local development servers for API and web frontend testing.

### 4A: Python Virtual Environment & API Dependencies

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 4.1 | Create Python Virtual Environment | `python -m venv .venv` (from project root) | 1.2 | Completed | Isolates project dependencies |
| 4.2 | Activate Virtual Environment | **Linux/Mac:** `source .venv/bin/activate`<br>**Windows:** `.\.venv\Scripts\activate` | 4.1 | Completed | Required before pip install |
| 4.3 | Upgrade pip | `python -m pip install --upgrade pip` | 4.2 | Completed | Ensures latest pip version |
| 4.4 | Install API Dependencies | `cd src/api && pip install -r requirements.txt` | 4.2, 3.2 | Completed | Installs: fastapi, prompty, azure-ai-projects, azure-search-documents, etc. |
| 4.5 | Verify Installation | `pip list \| grep -E "fastapi\|prompty\|azure"` | 4.4 | Completed | Confirms key packages present |

### 4B: Web Frontend Dependencies

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 4.6 | Install Node Dependencies | `cd src/web && npm install` | 1.4 | Completed | Creates node_modules/ with React and build tools |
| 4.7 | Verify npm Installation | `npm list react` (from src/web) | 4.6 | Completed | Confirms React properly installed |

**Phase 4 Completion Criteria:**
- `.venv/` directory exists and activation works
- `pip list` shows fastapi, prompty, uvicorn, azure-ai-projects
- `src/web/node_modules/` directory exists with >1000 packages
- No installation errors in console output

---

## Phase 5: Local Testing

Test API and web frontend locally before deployment.

### 5A: API Server Testing

| Task | Description | Commands | Port | Status | Notes |
|------|-------------|----------|------|--------|-------|
| 5.1 | Activate Virtual Environment | From src/api: `source ../../.venv/bin/activate` (Linux/Mac) | N/A | Pending | Ensures correct Python environment |
| 5.2 | Start FastAPI Development Server | From src/api: `fastapi dev main.py` | 8000 | Pending | Runs with auto-reload on file changes |
| 5.3 | Test Root Endpoint | Open browser: `http://127.0.0.1:8000/` | 8000 | Pending | Should return: `{"message": "Hello World"}` |
| 5.4 | Test Article Generation Endpoint | POST to `http://127.0.0.1:8000/api/article` with JSON payload | 8000 | Pending | Request body: `{"research": "...", "products": "...", "assignment": "..."}` |
| 5.5 | Monitor Agent Workflow | Enable DEBUG logging: set `LOCAL_TRACING=true` before running server | 8000 | Pending | Creates `.runs/` folder with execution traces |
| 5.6 | Test Image Upload Endpoint | POST binary image to `/api/upload-image` | 8000 | Pending | Returns safety evaluation of image |

**Test Payload Example** (5.4):
```json
{
  "research": "camping in alaska",
  "products": "tent, sleeping bag, backpack",
  "assignment": "find specifics about what type of gear they would need and explain in detail"
}
```

**Expected Response:** Server-Sent Events (SSE) stream with agent progress updates

### 5B: Web Frontend Testing

| Task | Description | Commands | Port | Status | Notes |
|------|-------------|----------|------|--------|-------|
| 5.7 | Start Web Development Server | From src/web: `npm run dev` | 5173 | Pending | Launches Vite dev server with HMR |
| 5.8 | Access Web UI | Open browser: `http://localhost:5173` | 5173 | Pending | React app should load with Creative Team interface |
| 5.9 | Test Article Creation Form | Enter topic and instructions in UI | 5173 | Pending | Form should accept text input and enable "Start Work" button |
| 5.10 | Test Agent Workflow Display | Click "Start Work" and observe agent progress | 5173 | Pending | Should show: Researcher → Product Agent → Writer → Editor |
| 5.11 | Test Debug Panel | Click debug button (bottom right corner) | 5173 | Pending | Displays real-time agent execution details |
| 5.12 | Verify API Integration | Check browser DevTools Network tab for POST requests to API | 5173 | Pending | Requests should target `http://127.0.0.1:8000/api/article` |

**Phase 5 Completion Criteria:**
- `fastapi dev main.py` starts without errors
- Root endpoint returns JSON response
- `/api/article` POST request accepted and returns SSE stream
- `npm run dev` starts without errors
- Web UI loads with form fields visible
- Form submission triggers API calls visible in Network tab
- Agent workflow completes and article displays

---

## Phase 6: Evaluation & Quality Assurance

Assess application quality using built-in evaluators.

| Task | Description | Commands | Metrics | Status | Notes |
|------|-------------|----------|---------|--------|-------|
| 6.1 | Review Evaluation Inputs | Read `src/api/evaluate/eval_inputs.jsonl` | N/A | Pending | Contains 3 pre-built examples with research, products, assignments |
| 6.2 | Run Evaluation Suite | From src/api: `python -m evaluate.evaluate` | Coherence, Fluency, Relevance, Groundedness | Pending | Takes 5-10 minutes; requires Azure OpenAI access |
| 6.3 | Verify Evaluation Scores | Check console output for metric scores | Range: 1-5 (higher is better) | Pending | Each example receives 4 quality scores |
| 6.4 | Analyze Results | Review which agents produce highest quality output | N/A | Pending | Identifies optimization opportunities |
| 6.5 | (Optional) Custom Evaluation | Create custom eval_inputs.jsonl entries for domain-specific testing | N/A | Pending | Add scenarios matching your use cases |

**Evaluation Metrics:**
- **Coherence (1-5):** Logical flow and structure of article
- **Fluency (1-5):** Readability and natural language quality
- **Relevance (1-5):** How well article addresses the topic
- **Groundedness (1-5):** Facts supported by research and products

**Phase 6 Completion Criteria:**
- `python -m evaluate.evaluate` completes without errors
- All 4 metrics return scores between 1-5
- Each evaluation example shows scores > 3.0 (minimum acceptable quality)
- Output saved to console and logs for review

---

## Phase 7: Deployment to Azure Container Apps

Deploy application to cloud infrastructure.

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 7.1 | Ensure All Local Tests Pass | Run Phase 5 tests successfully | 5.1-5.12 | Pending | Verify before pushing to cloud |
| 7.2 | Commit Code to Git | `git add . && git commit -m "Ready for deployment"` | All phases | Pending | Creates deployment snapshot |
| 7.3 | Deploy via azd | From project root: `azd up` | 1.6, 1.7 | Pending | Builds containers and deploys to Container Apps |
| 7.4 | Monitor Deployment | Check Azure Portal: Container Apps > Deployments | 7.3 | Pending | Should show "Succeeded" status |
| 7.5 | Verify API Container | Navigate to API Container App in Portal, check Ingress URL | 7.3 | Pending | API should be accessible at public URL |
| 7.6 | Verify Web Container | Navigate to Web Container App in Portal, check Ingress URL | 7.3 | Pending | Web UI should be accessible at public URL |
| 7.7 | Test Cloud Deployment | POST to cloud API endpoint with test payload | 7.5, 7.6 | Pending | Should generate article successfully |
| 7.8 | Verify Application Insights Logging | Check Application Insights in Portal for requests/errors | 7.3 | Pending | Should show request traces and performance metrics |

**Phase 7 Completion Criteria:**
- No deployment errors in azd output
- Both Container Apps show "Succeeded" in Portal
- API and Web Ingress URLs are publicly accessible
- Cloud-hosted API responds to article generation requests
- Application Insights shows telemetry data

---

## Phase 8: CI/CD Pipeline Setup (Optional)

Automate testing and deployment with GitHub Actions.

| Task | Description | Commands | Dependencies | Status | Notes |
|------|-------------|----------|-------------|--------|-------|
| 8.1 | Configure GitHub Actions | From project root: `azd pipeline config` | 1.7, Git repo | Pending | Sets up GitHub secrets and workflows |
| 8.2 | Review Generated Workflow Files | Check `.github/workflows/` for `azure-dev.yml` | 8.1 | Pending | Auto-generated pipeline configuration |
| 8.3 | Verify GitHub Secrets | In GitHub repo settings, check Actions secrets for `AZURE_*` values | 8.1 | Pending | Required for CI/CD authentication |
| 8.4 | Push to Main Branch | `git push origin main` | All phases, 8.1 | Pending | Triggers GitHub Actions workflow |
| 8.5 | Monitor Workflow Run | Check GitHub Actions tab in browser | 8.4 | Pending | Should show build, test, and deploy steps |
| 8.6 | Verify Cloud Deployment | Check Container Apps for updated deployment | 8.5 | Pending | New version should be running automatically |

**Phase 8 Completion Criteria:**
- `azd pipeline config` completes without errors
- GitHub Actions workflow file exists and is valid YAML
- First push to main triggers workflow run
- Workflow completes with "success" status
- Cloud deployment updates to new code version

---

## Key Files & Components

### Backend Architecture

| File | Purpose | Key Classes/Functions |
|------|---------|----------------------|
| `src/api/main.py` | FastAPI application entry point | `app`, `create_article()`, `upload_image()` |
| `src/api/orchestrator.py` | Multi-agent orchestration flow | `Task`, `create()`, `start_message()`, `complete_message()` |
| `src/api/agents/researcher/researcher.py` | Bing Search grounding research agent | Calls Bing Grounding Tool to research topics |
| `src/api/agents/product/product.py` | AI Search product lookup agent | Semantic search in `contoso-products` index |
| `src/api/agents/writer/writer.py` | Article composition agent | Combines research + products into article draft |
| `src/api/agents/editor/editor.py` | Article review and refinement agent | Polishes and fact-checks article |
| `src/api/evaluate/evaluate.py` | Quality evaluation runner | Orchestrates coherence, fluency, relevance, groundedness checks |
| `src/api/telemetry.py` | OpenTelemetry instrumentation | Sends metrics to Application Insights |
| `src/api/tracing.py` | Prompty execution tracing | Records `.runs/` traces for debugging |

### Frontend Architecture

| File | Purpose | Key Components |
|------|---------|-----------------|
| `src/web/src/App.tsx` | React application root | Main component and routing |
| `src/web/src/pages/CreativeTeam.tsx` | Agent workflow display | Shows each agent's progress and output |
| `src/web/src/components/ArticleForm.tsx` | Topic/instruction input form | Captures user requirements |
| `src/web/src/components/DebugPanel.tsx` | Execution details viewer | Real-time agent activity display |
| `src/web/src/services/apiClient.ts` | API communication | HTTP client for `/api/article` endpoint |

### Infrastructure

| File | Purpose | Scope |
|------|---------|-------|
| `infra/main.bicep` | Main infrastructure template | Defines all Azure resources |
| `infra/hooks/postprovision.sh` | Post-deployment setup | Runs after `azd up` completes |
| `infra/hooks/postprovision.ps1` | Windows equivalent hook | Same as .sh but for Windows PowerShell |
| `azure.yaml` | Azure Developer CLI config | Service definitions and hook configuration |

### Configuration Files

| File | Purpose |
|------|---------|
| `src/api/.env.sample` | Template for environment variables |
| `.env` | Generated at runtime (not committed) |
| `.azure/{env-name}/.env` | Environment-specific configuration |
| `src/api/requirements.txt` | Python package dependencies |
| `src/web/package.json` | Node.js package dependencies |

---

## Common Commands Reference

### Azure Developer CLI
```bash
azd auth login                          # Authenticate with Azure
azd init -t contoso-creative-writer     # Initialize project
azd up                                  # Provision infrastructure + deploy
azd deploy                              # Redeploy without reprovisioning
azd down                                # Delete all Azure resources
azd pipeline config                     # Setup GitHub Actions CI/CD
```

### Local Development
```bash
# API Server
cd src/api
source ../../.venv/bin/activate         # Activate venv (Linux/Mac)
fastapi dev main.py                     # Start API on port 8000

# Web Frontend
cd src/web
npm install                             # Install dependencies
npm run dev                             # Start dev server on port 5173
npm run build                           # Build production bundle

# Testing & Evaluation
cd src/api
python -m orchestrator                  # Run agent workflow standalone
python -m evaluate.evaluate             # Run quality evaluations
```

### Azure CLI
```bash
az account show                         # Show current subscription
az group list                           # List resource groups
az search documents list                # Query AI Search index
az container app list                   # List Container Apps
```

### Tracing & Debugging
```bash
export LOCAL_TRACING=true               # Enable Prompty tracing
cd src/api && python -m orchestrator    # Run with tracing enabled
# Check .runs/ folder for .tracy files
```

---

## Troubleshooting Quick Reference

| Issue | Cause | Solution |
|-------|-------|----------|
| `azd up` fails with region error | Selected region doesn't support gpt-4o | Choose eastus2, swedencentral, northcentralus, or francecentral |
| API returns 401 errors | Missing/invalid AZURE_OPENAI_ENDPOINT | Verify `.env` populated correctly; re-run `azd env get-values > .env` |
| Web UI can't reach API | CORS misconfiguration | Check `origins` list in `src/api/main.py`; add localhost if needed |
| Postprovision hook fails | Missing Jupyter kernel | Run `jupyter kernelspec list` to verify; reinstall if needed |
| Product data not indexed | `create-azure-search.ipynb` failed | Run manually: `jupyter nbconvert --execute data/create-azure-search.ipynb` |
| Port 8000/5173 already in use | Another process using port | Kill process: `lsof -ti:8000` or use different port with `fastapi dev --port 8001` |
| Image upload fails | Safety evaluation error | Check Azure AI Project exists and has evaluation permissions |
| Evaluation scores very low | Poor quality content | Review agent prompts in `agents/*/` directories; adjust for your domain |

---

## Success Criteria Summary

### Phase 1: ✅ All tools installed and authenticated
- `azd --version`, `python --version`, `docker ps`, `npm --version` all work
- `azd auth login` and `az login` successful
- `az account show` displays subscription

### Phase 2: ✅ Infrastructure provisioned
- All 11 resource types visible in Azure Portal
- No errors in `azd up` output
- Container Apps showing "Succeeded" status

### Phase 3: ✅ Post-provisioning complete
- `.env` file exists with all variables
- `contoso-products` index populated in AI Search
- No errors in postprovision script

### Phase 4: ✅ Local environment ready
- Python venv activated with all dependencies
- Node modules installed successfully
- No import errors when starting servers

### Phase 5: ✅ Local testing passing
- API responds to requests on port 8000
- Web UI accessible on port 5173
- Agent workflow completes and generates article
- No network errors in browser console

### Phase 6: ✅ Quality metrics acceptable
- All 4 evaluation metrics return scores 3.0+
- No errors in evaluation pipeline
- Results can be reviewed and compared

### Phase 7: ✅ Cloud deployment successful
- Container Apps show "Succeeded" deployment
- Cloud API and Web URLs publicly accessible
- Can generate articles via cloud endpoint
- Application Insights shows request telemetry

### Phase 8 (Optional): ✅ CI/CD automated
- GitHub Actions workflow runs on push
- Automated tests and deployment succeed
- Code changes automatically deployed to cloud

---

## Notes & Important Reminders

1. **Region Constraints:** gpt-4o availability varies by region. eastus2 is strongly recommended.

2. **API Version:** Set to `2024-08-01-preview` - do not change without testing compatibility.

3. **Bing Grounding:** Requires 80+ TPM allocation for gpt-4o. Check quota before deployment.

4. **Windows Users:** Use Git Bash for shell scripts. Convert line endings of `postprovision.sh` from CRLF to LF if on Windows.

5. **Codespaces Users:** Set port visibility to "Public" for ports 8000 and 5173 in VS Code Ports tab.

6. **Cost Monitoring:** Enable cost alerts in Azure Subscription to monitor gpt-4o usage (can be expensive).

7. **Data Retention:** Product data in AI Search is not deleted with `azd down` - manually delete index if needed.

8. **Local Tracing:** Enable with `export LOCAL_TRACING=true` to debug agent workflows. Creates `.runs/` folder with `.tracy` files.

---

## Additional Resources

- **Prompty Documentation:** https://prompty.ai/
- **Azure OpenAI Quickstart:** https://learn.microsoft.com/en-us/azure/developer/ai/get-started-multi-agents
- **Azure AI Search Semantic Search:** https://learn.microsoft.com/en-us/azure/search/semantic-search-overview
- **Bing Grounding Tool:** https://learn.microsoft.com/en-us/azure/ai-services/agents/how-to/tools/bing-grounding
- **FastAPI Documentation:** https://fastapi.tiangolo.com/
- **React Documentation:** https://react.dev/

---

**Document Version:** 1.0
**Last Updated:** 2026-02-18
**Template Version:** creativeagent@0.0.1-beta
