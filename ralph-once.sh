#!/usr/bin/env bash
# ralph-once.sh — Run one iteration of the Ralph Loop
# Usage: ./ralph-once.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

claude --permission-mode acceptEdits \
  --print \
  --prompt "You are working on the Étnicos Tienda Accesorios e-commerce project.

Read PRD.md for the full task list and progress.txt for what has been completed so far.

RULES:
- ONLY DO ONE TASK AT A TIME
- Pick the next unchecked task from PRD.md
- Implement it fully
- Mark it as done in PRD.md by changing [ ] to [x]
- Update progress.txt with what you did and any notes
- Commit your changes with a descriptive message
- If ALL tasks are complete, output exactly: <promise>COMPLETE</promise>

IMPORTANT: Follow the patterns already in the codebase. Read existing payment packages (Stripe, PayU) before implementing Wompi. Read docker-compose.yml before creating production Docker files."
