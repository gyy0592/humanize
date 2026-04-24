#!/bin/bash
#
# Ask Claude - One-shot consultation with a fresh Claude instance
#
# Sends a question or task to claude -p and returns the response.
# This is an active, one-shot skill (unlike the passive RLCR loop).
#
# Usage:
#   ask-claude.sh [--claude-model MODEL] [--claude-timeout SECONDS] [question...]
#
# Output:
#   stdout: Claude's response (for the caller to read)
#   stderr: Status/debug info (model, log paths)
#
# Storage:
#   Project-local: .humanize/skill/<unique-id>/{input,output,metadata}.md
#   Cache: ~/.cache/humanize/<sanitized-path>/skill-<unique-id>/claude-run.{cmd,out,log}
#

set -euo pipefail

# ========================================
# Source Shared Libraries
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source portable timeout wrapper
source "$SCRIPT_DIR/portable-timeout.sh"

# ========================================
# Default Configuration
# ========================================

DEFAULT_CLAUDE_MODEL="opus"
DEFAULT_CLAUDE_TIMEOUT=3600

CLAUDE_MODEL="$DEFAULT_CLAUDE_MODEL"
CLAUDE_TIMEOUT="$DEFAULT_CLAUDE_TIMEOUT"

# ========================================
# Help
# ========================================

show_help() {
    cat << 'HELP_EOF'
ask-claude - One-shot consultation with a fresh Claude instance

USAGE:
  /humanize:ask-claude [OPTIONS] <question or task>

OPTIONS:
  --claude-model <MODEL>
                       Claude model to use: sonnet, haiku, opus, or full model ID
                       like claude-sonnet-4-20250514 (default: sonnet)
  --claude-timeout <SECONDS>
                       Timeout for the Claude query in seconds (default: 3600)
  -h, --help           Show this help message

DESCRIPTION:
  Sends a one-shot question or task to a fresh, zero-context Claude instance
  (claude -p) and returns the response. Unlike the RLCR loop, this is
  a single consultation without iteration.

  The response is saved to .humanize/skill/<unique-id>/output.md for reference.

EXAMPLES:
  /humanize:ask-claude How should I structure the authentication module?
  /humanize:ask-claude --claude-model opus What are the performance bottlenecks?
  /humanize:ask-claude --claude-timeout 300 Review the error handling in src/api/
HELP_EOF
    exit 0
}

# ========================================
# Parse Arguments
# ========================================

QUESTION_PARTS=()
OPTIONS_DONE=false

while [[ $# -gt 0 ]]; do
    if [[ "$OPTIONS_DONE" == "true" ]]; then
        QUESTION_PARTS+=("$1")
        shift
        continue
    fi
    case $1 in
        -h|--help)
            show_help
            ;;
        --)
            OPTIONS_DONE=true
            shift
            ;;
        --claude-model)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --claude-model requires an argument (e.g., sonnet, haiku, opus, or claude-sonnet-4-20250514)" >&2
                exit 1
            fi
            # Accept known aliases or full claude model IDs
            if [[ "$2" != "sonnet" && "$2" != "haiku" && "$2" != "opus" && ! "$2" =~ ^claude- ]]; then
                echo "Error: --claude-model must be 'sonnet', 'haiku', 'opus', or a full Claude model ID (e.g., claude-sonnet-4-20250514), got: $2" >&2
                exit 1
            fi
            CLAUDE_MODEL="$2"
            shift 2
            ;;
        --claude-timeout)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --claude-timeout requires a number argument (seconds)" >&2
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --claude-timeout must be a positive integer (seconds), got: $2" >&2
                exit 1
            fi
            CLAUDE_TIMEOUT="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            QUESTION_PARTS+=("$1")
            OPTIONS_DONE=true
            shift
            ;;
    esac
done

QUESTION="${QUESTION_PARTS[*]}"

# ========================================
# Validate Prerequisites
# ========================================

if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' command is not installed or not in PATH" >&2
    echo "" >&2
    echo "Please install Claude Code CLI: https://docs.anthropic.com/en/docs/claude-code" >&2
    echo "Then retry: /humanize:ask-claude <your question>" >&2
    exit 1
fi

if [[ -z "$QUESTION" ]]; then
    echo "Error: No question or task provided" >&2
    echo "" >&2
    echo "Usage: /humanize:ask-claude [OPTIONS] <question or task>" >&2
    echo "" >&2
    echo "For help: /humanize:ask-claude --help" >&2
    exit 1
fi

# ========================================
# Detect Project Root
# ========================================

if git rev-parse --show-toplevel &>/dev/null; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel)
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi

# ========================================
# Create Storage Directories
# ========================================

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
UNIQUE_ID="${TIMESTAMP}-$$-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

SKILL_DIR="$PROJECT_ROOT/.humanize/skill/$UNIQUE_ID"
mkdir -p "$SKILL_DIR"

SANITIZED_PROJECT_PATH=$(echo "$PROJECT_ROOT" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$CACHE_BASE/humanize/$SANITIZED_PROJECT_PATH/skill-$UNIQUE_ID"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="$SKILL_DIR/cache"
    mkdir -p "$CACHE_DIR"
    echo "ask-claude: warning: home cache not writable, using $CACHE_DIR" >&2
fi

# ========================================
# Save Input
# ========================================

cat > "$SKILL_DIR/input.md" << EOF
# Ask Claude Input

## Question

$QUESTION

## Configuration

- Model: $CLAUDE_MODEL
- Timeout: ${CLAUDE_TIMEOUT}s
- Timestamp: $TIMESTAMP
EOF

# ========================================
# Save Debug Command
# ========================================

CLAUDE_CMD_FILE="$CACHE_DIR/claude-run.cmd"
CLAUDE_STDOUT_FILE="$CACHE_DIR/claude-run.out"
CLAUDE_STDERR_FILE="$CACHE_DIR/claude-run.log"

{
    echo "# Claude ask-claude invocation debug info"
    echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Working directory: $PROJECT_ROOT"
    echo "# Timeout: $CLAUDE_TIMEOUT seconds"
    echo ""
    echo "printf '%s' \"\$QUESTION\" | claude -p --model $CLAUDE_MODEL --permission-mode bypassPermissions --add-dir \"$PROJECT_ROOT\" -"
    echo ""
    echo "# Prompt content:"
    echo "$QUESTION"
} > "$CLAUDE_CMD_FILE"

# ========================================
# Run Claude
# ========================================

echo "ask-claude: model=$CLAUDE_MODEL timeout=${CLAUDE_TIMEOUT}s" >&2
echo "ask-claude: cache=$CACHE_DIR" >&2
echo "ask-claude: running claude -p..." >&2

epoch_to_iso() {
    local epoch="$1"
    date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    echo "unknown"
}

START_TIME=$(date +%s)

CLAUDE_EXIT_CODE=0
printf '%s' "$QUESTION" | run_with_timeout "$CLAUDE_TIMEOUT" \
    claude -p --model "$CLAUDE_MODEL" --permission-mode bypassPermissions --add-dir "$PROJECT_ROOT" - \
    > "$CLAUDE_STDOUT_FILE" 2> "$CLAUDE_STDERR_FILE" || CLAUDE_EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "ask-claude: exit_code=$CLAUDE_EXIT_CODE duration=${DURATION}s" >&2

# ========================================
# Handle Results
# ========================================

if [[ $CLAUDE_EXIT_CODE -eq 124 ]]; then
    echo "Error: Claude timed out after ${CLAUDE_TIMEOUT} seconds" >&2
    echo "" >&2
    echo "Try increasing the timeout:" >&2
    echo "  /humanize:ask-claude --claude-timeout $((CLAUDE_TIMEOUT * 2)) <your question>" >&2
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    cat > "$SKILL_DIR/metadata.md" << EOF
---
model: $CLAUDE_MODEL
timeout: $CLAUDE_TIMEOUT
exit_code: 124
duration: ${DURATION}s
status: timeout
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 124
fi

if [[ $CLAUDE_EXIT_CODE -ne 0 ]]; then
    echo "Error: Claude exited with code $CLAUDE_EXIT_CODE" >&2
    if [[ -s "$CLAUDE_STDERR_FILE" ]]; then
        echo "" >&2
        echo "Claude stderr (last 20 lines):" >&2
        tail -20 "$CLAUDE_STDERR_FILE" >&2
    fi
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    cat > "$SKILL_DIR/metadata.md" << EOF
---
model: $CLAUDE_MODEL
timeout: $CLAUDE_TIMEOUT
exit_code: $CLAUDE_EXIT_CODE
duration: ${DURATION}s
status: error
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit "$CLAUDE_EXIT_CODE"
fi

if [[ ! -s "$CLAUDE_STDOUT_FILE" ]]; then
    echo "Error: Claude returned empty response" >&2
    if [[ -s "$CLAUDE_STDERR_FILE" ]]; then
        echo "" >&2
        echo "Claude stderr (last 20 lines):" >&2
        tail -20 "$CLAUDE_STDERR_FILE" >&2
    fi
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    cat > "$SKILL_DIR/metadata.md" << EOF
---
model: $CLAUDE_MODEL
timeout: $CLAUDE_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: empty_response
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 1
fi

# ========================================
# Save Output and Metadata
# ========================================

cp "$CLAUDE_STDOUT_FILE" "$SKILL_DIR/output.md"

cat > "$SKILL_DIR/metadata.md" << EOF
---
model: $CLAUDE_MODEL
timeout: $CLAUDE_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: success
started_at: $(epoch_to_iso "$START_TIME")
---
EOF

echo "ask-claude: response saved to $SKILL_DIR/output.md" >&2

# ========================================
# Output Response
# ========================================

cat "$CLAUDE_STDOUT_FILE"
