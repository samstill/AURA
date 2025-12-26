# Aura Routing Algorithm (v2)

The Aura Routing Algorithm is a latency-optimized decision engine that determines how to process user queries. It balances speed (latency) with intelligence (model capability).

## Core Philosophy
1.  **Always Acknowledge Instantly**: The user should never stare at a loading spinner.
2.  **Fast for Simple, Smart for Complex**: Don't use a PhD (smart model) to say "Hello".
3.  **Speculative Execution**: Start heavy tasks *while* streaming acknowledgment.

## Decision Architecture

The Router (`router_service.py`) classifies every query into one of three execution paths using a fast LLM (e.g. `gpt-4o-mini` or `gum-4.1-nano`).

### 1. FAST_SOLVER (Latency < 500ms)
Used for simple questions, greetings, facts, and jokes.
- **Route**: `Router` -> `LLM Service (Fast Model)` -> `User`
- **Output**: Direct streaming response.
- **Examples**: "Hi", "What is Python?", "Tell me a joke".

### 2. SECRETARY_PROTOCOL (Latency < 200ms TTFT)
Used for complex reasoning, planning, coding, or creative writing.
- **Route**: `Router` -> `Orchestrator`
- **Orchestration**:
    - **Thread A (Staller)**: Instantly streams an acknowledgment (e.g., "On it, checking that now...").
    - **Thread B (Agent)**: Runs the heavy model (e.g. `gemini-2.0-flash-exp` or `gpt-4o`) in parallel.
    - **Stitching**: The system effectively "stitches" the staller text and the agent response together seamlessly.
- **Examples**: "Plan my week", "Debug this code", "Write a story".

### 3. TOOL EXECUTION (Latency varies)
Used when a specific tool is required.
- **Route**: `Router` -> `Orchestrator` -> `Agent` -> `Tool`
- **Mechanism**: The router detects the tool intent (e.g., `TOOL:calendar`) and verifies availability in the `ToolRegistry`.
- **Examples**: "Check my calendar", "Send email to John".

## Implementation Details

### Router Logic (`router_service.py`)
The router uses a **Pure LLM Decision** model. Heuristics (like word count) have been removed in favor of semantic understanding.

**Prompt Strategy:**
```text
Classify into:
1. FAST: Simple chat (hi, facts, jokes)
2. SMART: Reasoning, coding, planning
3. TOOL:[name]: Explicit tool usage
```

**Fallback Mechanism:**
If the Router LLM fails (e.g., Rate Limit / 429), the system purely falls back to heuristics:
- Short query (< 4 words) -> `FAST_SOLVER`
- Long query -> `SECRETARY_PROTOCOL`

### Orchestrator (`orchestrator_service.py`)
The orchestrator manages the "Secretary Protocol".
1.  **Phase A**: Semantic Cache Check & Routing.
2.  **Phase B**: Parallel Staller + Agent.
3.  **Phase C**: Stitching (If Agent finishes while Staller is talking).
4.  **Phase D**: Async Handoff (If Agent takes too long, switch to background task).

## Semantic Cache
All responses (Fast and Smart) are cached in `Redis` / `Qdrant`.
- **Hit**: Returns cached response in < 10ms.
- **Miss**: Proceeds to routing.
