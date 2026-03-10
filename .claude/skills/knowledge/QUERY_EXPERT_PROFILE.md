# Query Expert Profile

Query the expert profile for a discipline to understand the intellectual foundations, first principles, and key patterns that guide expert agents in that domain.

## When to Use

- Before creating a new agent — check if an expert profile exists for the discipline
- When reviewing an agent's decisions against established expert principles
- When you need the luminaries, first principles, or anti-patterns for a specific domain

## MCP Resource

```
colony://knowledge/expert_profile?discipline=<discipline>
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `discipline` | yes | The discipline name (e.g., `elixir-otp`, `distributed-systems`, `llm-orchestration`) |

### Response

Returns structured data with the following shape:

```json
{
  "discipline": "elixir-otp",
  "description": "Elixir language and OTP patterns",
  "luminaries": [
    {"name": "José Valim", "contribution": "Created Elixir..."}
  ],
  "first_principles": [
    {"name": "Let it crash", "principle": "Design for recovery", "applied": "Use supervisors"}
  ],
  "non_negotiables": ["Never store derived state as source of truth"],
  "instincts": [
    {"trigger": "Process receiving too many messages", "response": "Split into multiple processes"}
  ],
  "anti_patterns": [
    {"pattern": "God GenServer", "why": "Violates single-responsibility"}
  ]
}
```

## How to Apply

Use the expert profile to:
1. **Ground your first principles** — Align your decision-making with the discipline's established wisdom
2. **Check instincts** — When you see a trigger pattern, apply the expert's instinctive response
3. **Avoid anti-patterns** — Before implementing, verify you're not falling into a known bad pattern
4. **Reference luminaries** — When explaining decisions, cite the luminary whose principle guides the choice
