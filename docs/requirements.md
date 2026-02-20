# Contoso Creative Writer - Requirements Document

## 1. Overview

**Product Name:** Contoso Creative Writer
**Version:** 1.0
**Date:** February 2026
**Status:** Production-Ready

### 1.1 Purpose

Contoso Creative Writer is a multi-agent AI creative writing assistant that enables users to generate well-researched, product-specific articles. The application leverages Azure OpenAI and intelligent agent orchestration to combine real-time research, product recommendations, and editorial refinement into a cohesive article generation workflow.

### 1.2 Business Value

- **Content Quality:** Combines research, product context, and editorial review to produce high-quality articles
- **Efficiency:** Automates multi-step content creation process with minimal human intervention
- **Trustworthiness:** Grounds articles in real web research and internal product data
- **Scalability:** Cloud-native architecture supports on-demand workload scaling

### 1.3 Target Users

- Content marketers creating product-focused articles
- Product teams developing marketing materials
- Knowledge workers requiring research-backed content generation

---

## 2. Functional Requirements

### 2.1 User Interface

#### FR-UI-001: Article Creation Form
- Users enter three required inputs:
  - **Research Topic:** The subject matter to research
  - **Product Context:** Information about products to include
  - **Writing Instructions:** Specific guidance for article style and tone
- Submit button to initiate article generation
- Real-time progress indicator showing agent activity
- Results displayed in a streamlined article view

#### FR-UI-002: Debug Panel
- Optional debug view (accessible via toolbar button)
- Displays real-time JSON output from each agent
- Shows agent execution sequence and timing
- Allows developers to inspect intermediate results for troubleshooting

#### FR-UI-003: Image Upload & Evaluation
- Image upload capability for article enhancement
- Automatic content safety evaluation on upload
- User-friendly warnings if images contain harmful or protected content
- Safe images approved for inclusion

#### FR-UI-004: Article Viewing & Navigation
- Rendered article display with markdown formatting
- Navigation between research, products, and final article views
- Copy-to-clipboard functionality for sharing results

### 2.2 Research Agent

#### FR-RESEARCH-001: Web Search & Grounding
- Uses Bing Grounding Tool integrated with Azure AI Agent Service
- Executes research based on user-provided topic
- Returns structured research findings with citations
- Implements retry logic with exponential backoff for reliability

#### FR-RESEARCH-002: Multi-Turn Research (Editor Feedback)
- Accepts feedback from Editor Agent
- Can refine research based on editor notes
- Supports up to 2 revision cycles before finalization
- Maintains conversation context across iterations

#### FR-RESEARCH-003: Output Format
- Returns research results as structured JSON
- Includes source URLs and relevant excerpts
- Provides formatted summary suitable for article integration

### 2.3 Product Agent

#### FR-PRODUCT-001: Semantic Search
- Queries Azure AI Search vector store using semantic similarity
- Generates embeddings for product context using text-embedding-ada-002
- Retrieves top 3 most relevant products per search query

#### FR-PRODUCT-002: Vector-Based Retrieval
- Maintains "contoso-products" index with pre-vectorized product catalog
- Performs k-nearest-neighbor search on content vectors
- Returns product metadata: ID, title, content, and URLs
- Handles duplicate removal across multiple search queries

#### FR-PRODUCT-003: Product Enrichment
- Deduplicates product results
- Structures output with product-specific attributes
- Provides formatted product recommendations for article integration

### 2.4 Writer Agent

#### FR-WRITER-001: Article Composition
- Synthesizes research findings and product recommendations
- Integrates user assignment context (tone, style, focus)
- Generates initial article draft combining all inputs
- Returns article content as streaming chunks

#### FR-WRITER-002: Streaming Output
- Streams article content in real-time via Server-Sent Events (SSE)
- Enables progressive rendering in frontend
- Provides immediate visual feedback to users
- Buffers output for performance optimization

#### FR-WRITER-003: Content Processing
- Post-processes generated article for consistency
- Validates markdown formatting
- Ensures proper heading hierarchy
- Handles special characters and encoding

### 2.5 Editor Agent

#### FR-EDITOR-001: Quality Review
- Reviews generated articles for:
  - Coherence and logical flow
  - Fluency and readability
  - Relevance to original research and product data
  - Groundedness to source materials
- Applies professional editing standards

#### FR-EDITOR-002: Revision Feedback
- Provides structured feedback on article quality
- Identifies specific improvement areas
- Supports up to 2 revision cycles with Research Agent
- Signals when article meets quality threshold

#### FR-EDITOR-003: Final Approval
- Determines when article is ready for delivery
- Marks revision cycles complete
- Passes final article to evaluation pipeline

### 2.6 Orchestration

#### FR-ORCHESTRATION-001: Multi-Agent Workflow
- Manages sequential and parallel execution of agents
- Implements standardized message format for inter-agent communication
- Provides task tracking and status updates

#### FR-ORCHESTRATION-002: Agent Communication Protocol
- JSON-based message format with required fields:
  - `type`: Agent identifier (researcher, products, writer, editor)
  - `message`: Human-readable status
  - `data`: Structured agent output
- Server-Sent Events (SSE) streaming to frontend
- Backward compatibility with streaming and non-streaming clients

#### FR-ORCHESTRATION-003: Error Handling
- Graceful degradation on agent failures
- Detailed error messages with recovery suggestions
- Logging for debugging and monitoring
- Timeout management for long-running operations

#### FR-ORCHESTRATION-004: Feedback Loop Management
- Captures Editor feedback for Research refinement
- Manages revision cycle counter (max 2)
- Implements decision logic for revision vs. finalization

---

## 3. Non-Functional Requirements

### 3.1 Performance

#### NFR-PERF-001: Response Time
- Article generation from submission to completion: <120 seconds (typical)
- Individual agent execution: <30 seconds each
- Research refinement cycles: <20 seconds each

#### NFR-PERF-002: Streaming Latency
- Time-to-first-article-text: <5 seconds after writer begins
- Streaming chunk delivery: <500ms per chunk
- Frontend rendering: Real-time without blocking

#### NFR-PERF-003: Scalability
- Support 10+ concurrent article generation requests
- Azure Container Apps auto-scaling handles peak loads
- Database queries (Azure AI Search) complete in <2 seconds

### 3.2 Reliability & Availability

#### NFR-RELIABILITY-001: Uptime
- Target 99.5% availability during business hours
- Azure Container Apps provides managed redundancy
- Automatic health checks and restart on failure

#### NFR-RELIABILITY-002: Fault Tolerance
- Retry logic with exponential backoff for transient failures
- Maximum 3 retry attempts per operation
- Graceful timeout after 300 seconds (5 minutes)

#### NFR-RELIABILITY-003: Data Persistence
- No permanent state stored between requests (stateless design)
- Article generation logs persisted for audit trails
- Evaluation results stored for quality tracking

### 3.3 Security

#### NFR-SECURITY-001: Authentication & Authorization
- Managed Identity authentication (no API keys or secrets in code)
- Azure Key Vault for sensitive configuration
- Role-Based Access Control (RBAC) on Azure services

#### NFR-SECURITY-002: Content Safety
- Image content evaluation via Azure AI safety models
- Detection of harmful, explicit, or protected content
- User warnings for unsafe content with rejection capability

#### NFR-SECURITY-003: Data Protection
- All communications via HTTPS/TLS 1.3
- Encryption at rest for stored evaluation data
- No sensitive data logged (PII, credentials, API keys)

#### NFR-SECURITY-004: Infrastructure Security
- Firewall rules limiting Azure AI Services access
- Private endpoints for internal communication
- Network isolation via Azure Container Apps
- Regular security scanning via GitHub Actions

### 3.4 Observability & Monitoring

#### NFR-OBS-001: Application Insights Tracing
- OpenTelemetry instrumentation for FastAPI
- Prompty tracing for AI/LLM operations
- Distributed tracing across agents
- Custom metrics and events for business logic

#### NFR-OBS-002: Logging
- Structured logging to Application Insights
- Log levels: DEBUG, INFO, WARNING, ERROR
- Request/response logging for API calls
- Performance metrics captured per agent

#### NFR-OBS-003: Metrics & Dashboards
- Request latency percentiles (p50, p95, p99)
- Error rates and failure types
- Agent execution times
- User activity metrics
- Custom dashboards in Azure Monitor

#### NFR-OBS-004: Local Tracing
- Optional local Prompty tracing server (via `LOCAL_TRACING=true`)
- `.runs` folder containing detailed execution traces
- Visual inspection of function call sequences

### 3.5 Quality & Evaluation

#### NFR-QUALITY-001: Evaluation Metrics
The application measures article quality across four dimensions:

- **Coherence (Score: 1-5):** Logical flow and organization of ideas
- **Fluency (Score: 1-5):** Readability and natural language quality
- **Relevance (Score: 1-5):** Alignment with research and product context
- **Groundedness (Score: 1-5):** Factual accuracy supported by sources

#### NFR-QUALITY-002: Evaluation Workflow
- Runs automatically after article generation
- Processes evaluation inputs from `eval_inputs.jsonl`
- Executes in GitHub Actions for CI/CD validation
- Results stored for trending and quality assurance

#### NFR-QUALITY-003: Evaluation Scale
- Minimum viable quality: Average score ≥3.0 per metric
- Target quality: Average score ≥4.0 per metric
- Perfect quality: All metrics ≥4.5

### 3.6 Maintainability & Operability

#### NFR-MAINT-001: Code Organization
- Modular agent architecture (researcher, product, writer, editor)
- Prompty files for prompt management and version control
- Clear separation of concerns (agents, orchestration, evaluation)
- Configuration management via environment variables

#### NFR-MAINT-002: Documentation
- Prompty format for self-documenting AI agents
- Inline code comments for complex logic
- Architecture Decision Records (ADRs) for design choices
- README with setup and deployment instructions

#### NFR-MAINT-003: Testing & Validation
- Evaluation framework for quality assurance
- Unit tests for utility functions
- Integration tests for agent workflows
- Local testing capabilities via Python orchestrator

#### NFR-MAINT-004: Deployment Automation
- Infrastructure-as-Code using Bicep
- Azure Developer CLI (azd) for one-command deployment
- GitHub Actions for CI/CD pipeline
- Automated rollback capabilities

---

## 4. System Architecture

### 4.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend (React 18)                    │
│     TypeScript • Vite • Redux Toolkit • Tailwind CSS        │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Backend (Python)                  │
│              Streaming Response (Server-Sent Events)        │
└────────────────┬────────────────────────────────────┬──────┘
                 │                                     │
         ┌───────▼────────┐             ┌─────────────▼──────┐
         │  Orchestrator  │             │   Evaluation       │
         │  Multi-Agent   │             │   Pipeline         │
         │  Coordination  │             │   (Gen-AI Evals)   │
         └───────┬────────┘             └────────────────────┘
                 │
     ┌───────────┼───────────┬──────────────┐
     │           │           │              │
     ▼           ▼           ▼              ▼
┌─────────┐ ┌────────┐ ┌────────┐ ┌─────────────┐
│Researcher│ │Product │ │ Writer │ │   Editor    │
│  Agent   │ │ Agent  │ │ Agent  │ │   Agent     │
└────┬────┘ └───┬────┘ └───┬────┘ └──────┬──────┘
     │          │          │             │
     │          │          │             │
     ▼          ▼          ▼             ▼
┌──────────┐ ┌──────────┐ ┌──────┐ ┌─────────────┐
│ Bing Web │ │ Azure AI │ │Azure │ │   Azure     │
│ Grounding│ │  Search  │ │OpenAI│ │   OpenAI    │
└──────────┘ └──────────┘ └──────┘ └─────────────┘
```

### 4.2 Component Interaction

#### Request Flow

1. **User Submission:** Frontend sends article request with research topic, product context, and instructions
2. **Orchestration:** Backend creates streaming response channel via SSE
3. **Research Phase:** Research Agent queries Bing Grounding Tool
4. **Product Discovery:** Product Agent searches Azure AI Search with embeddings
5. **Writing Phase:** Writer Agent synthesizes research + products into draft
6. **Editor Review:** Editor Agent evaluates and provides feedback
7. **Streaming Output:** Article content streamed to frontend in real-time
8. **Evaluation:** Background evaluation job assesses quality metrics

#### Data Flow

```
User Input
  ├─ Research Context
  ├─ Product Context
  └─ Writing Instructions
         │
         ▼
  [Orchestrator]
         │
    ┌────┴────┐
    │ Research │  ─→ Bing API ─→ Web Results + Citations
    └────┬────┘
         │
    ┌────┴────┐
    │ Product  │  ─→ Azure AI Search ─→ Top 3 Products
    └────┬────┘
         │
    ┌────┴────┐
    │ Writer   │  ─→ Azure OpenAI ─→ Article Draft
    └────┬────┘
         │
    ┌────┴────┐
    │ Editor   │  ─→ Quality Evaluation ─→ Feedback/Approval
    └────┬────┘
         │
         ▼
    Final Article ──→ Frontend (Streamed)
         │
         └──→ Evaluation Pipeline ──→ Quality Metrics
```

### 4.3 Technology Stack

#### Backend

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Framework | FastAPI | HTTP API and async request handling |
| Language | Python 3.10+ | Core business logic implementation |
| AI Prompts | Prompty | Declarative prompt management |
| Streaming | Server-Sent Events (SSE) | Real-time article streaming |
| Agents | Azure AI Agent Service | Multi-agent orchestration |
| Tracing | OpenTelemetry + Prompty Tracer | Distributed request tracing |
| Telemetry | Application Insights | Monitoring and diagnostics |

#### Frontend

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Framework | React 18 | UI component framework |
| Language | TypeScript | Type-safe frontend code |
| Build Tool | Vite | Fast bundling and dev server |
| Styling | Tailwind CSS | Utility-first CSS framework |
| State Management | Redux Toolkit | Global state management |
| HTTP Client | Axios | REST API communication |
| Markdown | react-remark | Markdown rendering |

#### Infrastructure & DevOps

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Container Orchestration | Azure Container Apps | Serverless container deployment |
| Container Registry | Azure Container Registry | Docker image storage |
| Infrastructure-as-Code | Bicep | Azure resource provisioning |
| Deployment CLI | Azure Developer CLI (azd) | One-command infrastructure setup |
| CI/CD | GitHub Actions | Automated testing and deployment |
| Local Development | Docker Compose | Local environment setup |

---

## 5. Azure Services & Configuration

### 5.1 Azure AI Services

#### Azure OpenAI

| Model | Purpose | Deployment Name | TPM Requirement |
|-------|---------|-----------------|-----------------|
| gpt-4o | General-purpose agent reasoning | gpt-4 | 80+ TPM |
| gpt-4o-mini | Cost-effective agent reasoning | gpt-4-mini | 10 TPM |
| text-embedding-ada-002 | Product semantic search | text-embedding-ada-002 | 5 TPM |

**API Version:** 2024-08-01-preview
**Authentication:** Managed Identity (DefaultAzureCredential)

#### Azure AI Search

| Property | Value |
|----------|-------|
| Index Name | contoso-products |
| Vector Field | contentVector |
| Semantic Configuration | default |
| Query Type | Semantic Search |
| Top-K Results | 3 per query |
| Query Captions | Extractive |
| Query Answers | Extractive |

**Population:** Automatically seeded with product catalog during `azd up`

#### Azure AI Agent Service

| Feature | Configuration |
|---------|----------------|
| Agent Type | Azure OpenAI |
| Tools Available | Bing Grounding Tool |
| Connection | Bing Search connection string |
| Thread Management | Per-request threads |

**Bing Connection Requirements:**
- Bing Search API subscription
- Connection name: "bing-connection"
- Pre-configured in Azure AI Project

#### Bing Grounding Tool

| Property | Value |
|----------|-------|
| Purpose | Web search for research queries |
| Data Source | Bing Web Search API |
| Results Format | Web pages with citations |
| Freshness | Real-time |

### 5.2 Supporting Azure Services

#### Application Insights

| Configuration | Value |
|---------------|-------|
| Instrumentation | FastAPI + OpenTelemetry |
| Log Retention | 30 days default |
| Sampling | Adaptive sampling enabled |
| Custom Events | Agent execution metrics |

**Dashboards:**
- Request latency and throughput
- Agent execution times
- Error rates and failure types
- User activity trends

#### Azure Key Vault

| Purpose | Secret Types |
|---------|-------------|
| Credential Storage | API keys, connection strings |
| Configuration | Environment-specific values |
| Access Control | RBAC-secured |

**Pre-configured Secrets:**
- AZURE_OPENAI_ENDPOINT
- AZURE_SEARCH_ENDPOINT
- AZURE_AI_PROJECT_NAME
- BING_SUBSCRIPTION_KEY

#### Azure Container Registry

| Configuration | Value |
|---------------|-------|
| Images | API and Web service containers |
| Build Triggers | GitHub Actions on push |
| Retention | Latest 10 tagged images |
| Access Control | Managed Identity authentication |

#### Azure Container Apps

| Service | Configuration | Port |
|---------|---------------|------|
| API Service | Python FastAPI container | 8000 |
| Web Service | React/Vite container | 80 |
| Health Checks | TCP probes every 10s | - |
| Auto-scaling | 1-10 replicas (CPU-based) | - |
| CORS | Configured for dev/prod origins | - |

#### Azure Monitor & Log Analytics

| Feature | Configuration |
|---------|---------------|
| Workspace | Shared across all services |
| Log Sources | Application Insights, Container Apps |
| Query Language | KQL (Kusto Query Language) |
| Alerts | Threshold-based on error rates |

### 5.3 Environment Variables

#### Required for Deployment

```
# Azure Subscription & Location
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_LOCATION
AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_NAME
AZURE_OPENAI_API_VERSION

# Azure AI Services
AZURE_AI_PROJECT_NAME
AI_SEARCH_ENDPOINT
AZURE_SEARCH_ENDPOINT
APPINSIGHTS_CONNECTIONSTRING

# Optional: Container Apps URLs
API_SERVICE_ACA_URI
WEB_SERVICE_ACA_URI
CODESPACE_NAME
```

#### Optional for Local Development

```
# Enable local Prompty tracing
LOCAL_TRACING=true

# OpenTelemetry configuration
OTEL_SDK_DISABLED=false
```

---

## 6. Data Flow & Processing

### 6.1 Request Processing Pipeline

```
User Submission
    │
    ├─ Validate Input (research, products, assignment)
    │
    ├─ Create SSE Stream Response
    │
    ├─ Initialize Orchestrator
    │   └─ Yield "Initializing Agent Service" message
    │
    ├─ Research Phase
    │   ├─ Execute Research Agent with Bing Grounding
    │   ├─ Yield research results
    │   └─ Store for downstream agents
    │
    ├─ Product Discovery Phase
    │   ├─ Generate embeddings for product context
    │   ├─ Query Azure AI Search index
    │   ├─ Deduplicate results
    │   ├─ Yield product results
    │   └─ Store for downstream agents
    │
    ├─ Writing Phase
    │   ├─ Combine research + products + instructions
    │   ├─ Call Writer Agent
    │   ├─ Stream article chunks to frontend
    │   └─ Yield completion message
    │
    ├─ Editor Review Phase
    │   ├─ Evaluate article quality
    │   ├─ Check revision count
    │   ├─ If feedback provided & retries < 2:
    │   │   └─ Loop back to Research with feedback
    │   └─ Otherwise finalize
    │
    └─ Evaluation Phase (Async)
        ├─ Extract article metrics
        ├─ Run quality evaluators
        └─ Store results in database
```

### 6.2 Agent-to-Agent Communication

#### Message Format

```json
{
  "type": "researcher|products|writer|editor|error|partial|message",
  "message": "Human-readable status description",
  "data": {
    "...": "Agent-specific output"
  }
}
```

#### Research Agent Output

```json
{
  "type": "researcher",
  "message": "Completed researcher task",
  "data": {
    "sources": [
      {
        "url": "https://example.com",
        "title": "Article Title",
        "snippet": "Relevant excerpt"
      }
    ],
    "summary": "Research findings summary"
  }
}
```

#### Product Agent Output

```json
{
  "type": "products",
  "message": "Completed marketing task",
  "data": {
    "products": [
      {
        "id": "product-123",
        "title": "Product Name",
        "content": "Product description",
        "url": "https://example.com/product"
      }
    ]
  }
}
```

#### Writer Agent Output (Streamed)

```
partial: "Article paragraph 1..."
partial: "Article paragraph 2..."
partial: "Article paragraph 3..."
```

#### Editor Agent Output

```json
{
  "type": "editor",
  "message": "Completed editor task",
  "data": {
    "quality_score": 4.2,
    "coherence": 4,
    "fluency": 4,
    "relevance": 4.5,
    "groundedness": 4,
    "feedback": "Minor improvements needed...",
    "revision_requested": false
  }
}
```

### 6.3 Image Evaluation Pipeline

```
Image Upload
    │
    ├─ Save to disk (web/public/*)
    │
    ├─ Call evaluate_image()
    │   ├─ Load Azure AI safety evaluators
    │   └─ Classify content (violence, hate, sexual, etc.)
    │
    ├─ Analyze Results
    │   ├─ If harmful content detected:
    │   │   └─ Return warning with violation types
    │   └─ Else:
    │       └─ Approve for use
    │
    └─ Return Verdict to Frontend
        └─ Display message and filename
```

---

## 7. Evaluation & Quality Metrics

### 7.1 Evaluation Framework

The application uses Azure's GenAI evaluation framework to measure article quality. Evaluations run:
- **Automatically:** After each article generation
- **In CI/CD:** During GitHub Actions workflow on push to main
- **On-Demand:** Via `python -m evaluate.evaluate` script

### 7.2 Quality Metrics

#### Metric 1: Coherence
- **Definition:** Logical flow and organization of ideas in the article
- **Scale:** 1-5 (1=scattered, 5=perfectly organized)
- **Evaluator:** Azure AI Coherence-Evaluator v4
- **Target:** ≥4.0

#### Metric 2: Fluency
- **Definition:** Readability and natural language quality
- **Scale:** 1-5 (1=unreadable, 5=natural, engaging prose)
- **Evaluator:** Azure AI Fluency-Evaluator v4
- **Target:** ≥4.0

#### Metric 3: Relevance
- **Definition:** Alignment of article content with research topic and product context
- **Scale:** 1-5 (1=off-topic, 5=highly relevant)
- **Evaluator:** Azure AI Relevance-Evaluator v4
- **Target:** ≥4.0

#### Metric 4: Groundedness
- **Definition:** Factual accuracy and support from source materials
- **Scale:** 1-5 (1=unsupported, 5=fully grounded)
- **Evaluator:** Azure AI Groundedness-Evaluator v4
- **Target:** ≥4.0

### 7.3 Content Safety Evaluation

#### Protected Content Detection

The system evaluates uploaded images for:

| Category | Description | Action |
|----------|-------------|--------|
| Violence | Violent or gory content | Warn & block |
| Hate & Unfairness | Hateful, biased, or discriminatory content | Warn & block |
| Sexual | Explicit sexual content | Warn & block |
| Self-Harm | Self-injury or endangerment | Warn & block |
| Protected Material | Copyrighted or trademarked content | Warn & block |

**Evaluators Used:**
- Violent-Content-Evaluator v3
- Hate-and-Unfairness-Evaluator v3
- Sexual-Content-Evaluator v3
- Self-Harm-Evaluator v3
- Protected-Material-Evaluator v3

### 7.4 Evaluation Input & Output

#### Input Format (eval_inputs.jsonl)

```json
{
  "research": "Research topic from article generation",
  "products": "Product context from article generation",
  "assignment": "Writing instructions from user",
  "article": "Generated article content"
}
```

**Default Test Cases:** 3 pre-configured examples in `eval_inputs.jsonl`

#### Output Format

```
Metric: Coherence
Score: 4.5

Metric: Fluency
Score: 4.2

Metric: Relevance
Score: 4.0

Metric: Groundedness
Score: 3.8

Overall Score: 4.125
```

### 7.5 Quality Threshold & Actions

| Overall Score | Status | Action |
|---------------|--------|--------|
| ≥4.0 | Excellent | Approve article |
| 3.5-3.9 | Good | Approve with minor notes |
| 3.0-3.4 | Acceptable | Approve (monitor quality) |
| <3.0 | Poor | Flag for review, investigate |

---

## 8. Deployment & Operations

### 8.1 Deployment Architecture

```
GitHub Repository
    │
    ├─ Infrastructure (Bicep IaC)
    ├─ Backend (Python FastAPI)
    ├─ Frontend (React TypeScript)
    └─ GitHub Actions Workflows
         │
         ├─ On PR: Run lint, test, quality checks
         ├─ On push main: Build, evaluate, deploy
         └─ On schedule: Run full evaluation suite
                │
                ▼
    Azure Container Registry (Push images)
                │
    ┌───────────┴───────────┐
    ▼                       ▼
API Service           Web Service
(Container Apps)      (Container Apps)
    │                       │
    ├─ Azure OpenAI ◄───────┤
    ├─ Azure AI Search ◄────┤
    ├─ Bing Grounding ◄─────┤
    ├─ App Insights ◄───────┤
    └─ Key Vault ◄──────────┘
```

### 8.2 One-Command Deployment

```bash
# Initial setup (provisions all Azure resources + deploys code)
azd up

# Subsequent deployments (code changes only)
azd deploy

# CI/CD setup (enables GitHub Actions automation)
azd pipeline config
```

### 8.3 Local Development Setup

```bash
# Backend
cd src/api
python -m venv .venv
source .venv/bin/activate  # or .\.venv\Scripts\activate on Windows
pip install -r requirements.txt
fastapi dev main.py  # Runs on http://localhost:8000

# Frontend (new terminal)
cd src/web
npm install
npm run dev  # Runs on http://localhost:5173

# Optional: Local tracing
export LOCAL_TRACING=true
python -m orchestrator  # Generates .runs folder with traces
```

### 8.4 Local Testing

#### Test with Python Orchestrator

```bash
cd src/api
python -m orchestrator
```

This runs the full article generation pipeline without the API/frontend, useful for debugging agent logic.

#### Test with Browser

```bash
# Terminal 1: API server
cd src/api && fastapi dev main.py

# Terminal 2: Frontend dev server
cd src/web && npm run dev

# Visit http://localhost:5173
```

#### API Testing (curl)

```bash
curl -X POST http://localhost:8000/api/article \
  -H "Content-Type: application/json" \
  -d '{
    "research": "Best practices for remote work",
    "products": "Productivity software",
    "assignment": "Write a professional guide"
  }'
```

### 8.5 Monitoring & Troubleshooting

#### View Logs

```bash
# Azure Container Apps logs
az containerapp logs show \
  --name api-service \
  --resource-group your-rg \
  --tail 50

# Application Insights logs
az monitor app-insights query \
  --app your-insights \
  --resource-group your-rg
```

#### Enable Detailed Tracing

```bash
# Set environment variable
export LOCAL_TRACING=true

# Run orchestrator
cd src/api && python -m orchestrator

# Inspect traces in .runs folder
```

#### Performance Analysis

- **Request Latency:** Application Insights → Performance
- **Agent Execution Times:** Custom metrics in App Insights
- **Error Rates:** Application Insights → Failures
- **Resource Usage:** Container Apps → Monitoring

---

## 9. Constraints & Assumptions

### 9.1 Constraints

| Constraint | Implication |
|-----------|------------|
| **gpt-4o TPM requirement:** 80+ | Must request quota increase; minimum 10 TPM for gpt-4o-mini |
| **Region availability:** Limited models | Use East US 2 recommended; check availability for gpt-4o, gpt-4o-mini |
| **Max revision cycles:** 2 | Editor can request max 2 refinements before finalizing |
| **Revision agent:** Research only | Only Research Agent receives feedback; Product, Writer, Editor run once |
| **Product index:** Pre-seeded | Must run data ingestion during deployment; no dynamic product uploads |
| **Managed Identity:** Required | No API key authentication; Entra ID credentials mandatory |
| **Streaming protocol:** SSE only | WebSocket alternative requires separate implementation |

### 9.2 Assumptions

| Assumption | Impact |
|-----------|--------|
| **Azure account available** | Project requires active Azure subscription |
| **Bing Grounding API enabled** | Research agent functionality depends on this service |
| **Docker available locally** | Local development and Container Apps deployment require Docker |
| **Git repository connected** | CI/CD pipeline assumes GitHub Actions and git integration |
| **Product catalog provided** | Data ingestion script assumes CSV/JSON product data |
| **User inputs are valid** | No extensive input validation; assumes well-formed text |
| **Research results exist** | Web search may return no results for obscure topics |
| **Network connectivity** | All external API calls assume internet connectivity |

---

## 10. Acceptance Criteria

The application is considered production-ready when:

### Functional Acceptance Criteria

- [x] User can submit article request with research, products, and instructions
- [x] Research Agent returns web search results via Bing Grounding
- [x] Product Agent retrieves 3+ relevant products from Azure AI Search
- [x] Writer Agent generates article combining research + products
- [x] Editor Agent reviews article and provides feedback
- [x] Article streams to frontend in real-time via SSE
- [x] Editor can request revision (max 2 cycles) with feedback
- [x] Image upload evaluates content safety
- [x] Debug panel displays agent output in real-time
- [x] Article rendering displays formatted markdown

### Non-Functional Acceptance Criteria

- [x] Article generation completes in <120 seconds
- [x] Streaming begins within 5 seconds
- [x] Handles 10+ concurrent requests
- [x] 99.5% uptime during business hours
- [x] All quality metrics average ≥3.0 (acceptable), ≥4.0 (target)
- [x] No API keys or secrets in code/logs
- [x] Application Insights captures all requests and errors
- [x] CI/CD pipeline runs on every push
- [x] One-command deployment with `azd up`
- [x] Local development via `npm run dev` + `fastapi dev`

---

## 11. Success Metrics & KPIs

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Article Generation Time** | <120 seconds | Time from submission to completion |
| **Streaming Latency** | <5 seconds | Time to first article text |
| **User Satisfaction** | ≥4.0/5.0 | Post-generation survey |
| **Coherence Score** | ≥4.0 | Automated evaluation metric |
| **Fluency Score** | ≥4.0 | Automated evaluation metric |
| **Relevance Score** | ≥4.0 | Automated evaluation metric |
| **Groundedness Score** | ≥4.0 | Automated evaluation metric |
| **Availability** | 99.5% | Uptime monitoring |
| **Error Rate** | <1% | Application Insights |
| **Cost per Article** | <$0.10 | Azure usage analytics |

---

## 12. Future Enhancements (Out of Scope)

The following features are identified for future development:

- [ ] **Conversation Memory:** Multi-turn article refinement with conversation history
- [ ] **Custom Agents:** User-defined agent personas (SEO specialist, technical writer, etc.)
- [ ] **Batch Article Generation:** Schedule multiple articles for generation
- [ ] **Template System:** Pre-defined article structures and formats
- [ ] **Collaborative Editing:** Real-time multi-user article refinement
- [ ] **Version Control:** Track article versions and revisions
- [ ] **Export Formats:** PDF, DOCX, LinkedIn, Medium integrations
- [ ] **Translation:** Multi-language article generation
- [ ] **Social Media:** Automatic social post generation from articles
- [ ] **Analytics Dashboard:** User analytics and content performance tracking
- [ ] **A/B Testing:** Prompt variant comparison and optimization

---

## 13. References & Related Documents

### Documentation

- [README.md](../README.md) - Project overview and quick start
- [Prompty Documentation](https://prompty.ai/) - Prompt management framework
- [Azure OpenAI Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [Azure AI Agent Service](https://learn.microsoft.com/en-us/azure/ai-services/agents/overview)
- [Bing Grounding Tool](https://learn.microsoft.com/en-us/azure/ai-services/agents/how-to/tools/bing-grounding)
- [Azure AI Search Documentation](https://learn.microsoft.com/en-us/azure/search/)

### Code Structure

```
azure-creative-writer/
├── src/
│   ├── api/
│   │   ├── main.py                 # FastAPI entry point
│   │   ├── orchestrator.py         # Multi-agent workflow
│   │   ├── agents/
│   │   │   ├── researcher/
│   │   │   ├── product/
│   │   │   ├── writer/
│   │   │   └── editor/
│   │   ├── evaluate/
│   │   │   ├── evaluate.py         # Evaluation runner
│   │   │   └── evaluators.py       # Quality metrics
│   │   ├── tracing.py              # OpenTelemetry setup
│   │   └── telemetry.py            # App Insights integration
│   └── web/
│       ├── src/
│       │   ├── main.tsx            # React entry point
│       │   ├── components/         # React components
│       │   └── store/              # Redux state
│       └── package.json            # Dependencies
├── infra/
│   ├── main.bicep                  # IaC definition
│   ├── ai.yaml                     # AI service config
│   └── hooks/                      # Post-deployment scripts
├── .github/
│   └── workflows/                  # CI/CD pipeline
├── data/
│   └── create-azure-search.py      # Data ingestion
└── docs/
    ├── requirements.md             # This document
    ├── README.md                   # Getting started
    └── deploy_lowcost.md           # Budget deployment guide
```

### Key Files by Agent

| Agent | Main Files | Purpose |
|-------|-----------|---------|
| Researcher | `agents/researcher/researcher.py` `.prompty` | Web search with Bing |
| Product | `agents/product/product.py` `.prompty` | Semantic search products |
| Writer | `agents/writer/writer.py` `.prompty` | Article composition |
| Editor | `agents/editor/editor.py` `.prompty` | Quality review & feedback |

---

## 14. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial requirements document for production release |

---

**Document Owner:** Product Team
**Last Updated:** February 18, 2026
**Status:** APPROVED FOR PRODUCTION
