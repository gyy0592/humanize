---
name: ask-claude
description: Consult a fresh Claude instance as an independent expert. Sends a question or task to claude -p and returns the response.
argument-hint: "[--claude-model MODEL] [--claude-timeout SECONDS] [question or task]"
allowed-tools: "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-claude.sh:*)"
---

# Ask Claude

Send a question or task to a fresh, zero-context Claude instance and return the response.

## How to Use

Do not pass free-form user text to the shell unquoted. The question or task may contain spaces or shell metacharacters such as `(`, `)`, `;`, `#`, `*`, or `[`.

If the user only supplied a question or task, execute:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-claude.sh" "$ARGUMENTS"
```

If the user supplied flags such as `--claude-model` or `--claude-timeout`, reconstruct the command so those flags remain separate shell arguments and the remaining free-form question is passed as one quoted final argument.

Example:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-claude.sh" --claude-model opus "Review the following round summary (M4)..."
```

Never run this unsafe form:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-claude.sh" $ARGUMENTS
```

because the shell will re-parse the question text and can fail before `ask-claude.sh` starts.

## Interpreting Output

- The script outputs Claude's response to **stdout** and status info to **stderr**
- Read the stdout output carefully and incorporate Claude's response into your answer
- If the script exits with a non-zero code, report the error to the user

## Error Handling

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success - Claude response is in stdout |
| 1 | Validation error (missing claude CLI, empty question, invalid flags) |
| 124 | Timeout - suggest using `--claude-timeout` with a larger value |
| Other | Claude process error - report the exit code and any stderr output |

## Notes

- The response is saved to `.humanize/skill/<timestamp>/output.md` for reference
- Default model is `sonnet` with a 3600-second timeout
- Available models: sonnet, haiku, opus
