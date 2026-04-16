---
name: consult-strategist
description: Read the project's strategic context before planning work. Consult overview files and the custom strategist agent for alignment.
---

# Consult Strategist

When decomposing a directive, read the project's strategic context before planning:

1. Read `.colony/overview/` — all files. These contain the strategic
   framework, assumptions, risk analysis, and constraints for this project.

2. Read `.claude/agents/{agent_type}.md` — the custom strategist's system
   prompt. This tells you what strategic frameworks apply and what the
   strategist cares about.

3. Check your proposed task plan against the strategic context:
   - Does every task serve the directive's stated objective?
   - Does any task depend on an assumption tagged [ASSUMED] or [UNKNOWN]?
     If so, consider whether the task should validate that assumption
     or whether it should be flagged as a risk.
   - Are tasks focused on the starting niche / primary audience, or
     spreading too wide?

4. If you have a question the overview files don't answer, flag it as
   an escalation. The strategist (or user) will update the overview
   files with the answer.

You do NOT need to invoke the strategist as a separate agent. The
overview files ARE the strategist's output. Read them, internalize
the context, and apply it to your decomposition.
