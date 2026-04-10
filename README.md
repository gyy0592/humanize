# Humanize

**Current Version: 1.15.1**

> Derived from the [GAAC (GitHub-as-a-Context)](https://github.com/SihaoLiu/gaac) project.

A Claude Code plugin that provides iterative development with independent AI review. Build with confidence through continuous feedback loops.

## What is RLCR?

**RLCR** stands for **Ralph-Loop with Codex Review**, inspired by the official ralph-loop plugin and enhanced with independent Codex review. The name also reads as **Reinforcement Learning with Code Review** -- reflecting the iterative cycle where AI-generated code is continuously refined through external review feedback.

## Core Concepts

- **Iteration over Perfection** -- Instead of expecting perfect output in one shot, Humanize leverages continuous feedback loops where issues are caught early and refined incrementally.
- **One Build + One Review** -- Claude implements, Codex independently reviews. No blind spots.
- **Ralph Loop with Swarm Mode** -- Iterative refinement continues until all acceptance criteria are met. Optionally parallelize with Agent Teams.
- **Begin with the End in Mind** -- Before the loop starts, Humanize verifies that *you* understand the plan you are about to execute. The human must remain the architect. ([Details](docs/usage.md#begin-with-the-end-in-mind))

## How It Works

<p align="center">
  <img src="docs/images/rlcr-workflow.svg" alt="RLCR Workflow" width="680"/>
</p>

The loop has two phases: **Implementation** (Claude works, Codex reviews summaries) and **Code Review** (Codex checks code quality with severity markers). Issues feed back into implementation until resolved.

## Install

```bash
# Add humania marketplace
/plugin marketplace add humania-org/humanize
# If you want to use development branch for experimental features
/plugin marketplace add humania-org/humanize#dev
# Then install humanize plugin
/plugin install humanize@humania
```

Requires [codex CLI](https://github.com/openai/codex) for review. See the full [Installation Guide](docs/install-for-claude.md) for prerequisites and alternative setup options.

## Quick Start

1. **Generate a plan** from your draft:
   ```bash
   /humanize:gen-plan --input draft.md --output docs/plan.md
   ```

2. **Refine an annotated plan** before implementation when reviewers add `CMT:` ... `ENDCMT` comments:
   ```bash
   /humanize:refine-plan --input docs/plan.md
   ```

3. **Run the loop**:
   ```bash
   /humanize:start-rlcr-loop docs/plan.md
   ```

4. **Monitor progress**:
   ```bash
   source <path/to/humanize>/scripts/humanize.sh
   humanize monitor rlcr
   ```

## Monitor Dashboard

<p align="center">
  <img src="docs/images/monitor.png" alt="Humanize Monitor" width="680"/>
</p>

## Using Third-Party Models (OpenRouter)

Humanize supports third-party model providers like [OpenRouter](https://openrouter.ai/) through the Codex CLI's custom provider configuration. This lets you use models like Nemotron, DeepSeek, Qwen, Gemini, and others for both implementation review and ask-codex queries.

### Setup

**1. Configure Codex CLI to use OpenRouter**

Edit `~/.codex/config.toml`:

```toml
model_provider = "crs"
model = "nvidia/nemotron-3-super-120b-a12b:free"

[model_providers.crs]
name = "crs"
base_url = "https://openrouter.ai/api/v1"
wire_api = "responses"
requires_openai_auth = true
```

Edit `~/.codex/auth.json`:

```json
{
  "auth_mode": "apikey",
  "OPENAI_API_KEY": "sk-or-v1-your-openrouter-api-key"
}
```

**2. Apply the OpenRouter compatibility patch**

OpenRouter model names contain `/` and `:` (e.g. `nvidia/nemotron-3-super-120b-a12b:free`), which the default humanize installation rejects. Run the patch script to fix this:

```bash
bash patches/fix-humanize-openrouter-model.sh
```

This patch:
- Relaxes model name validation to allow `/`, `:`, `+`
- Fixes the `MODEL:EFFORT` parser so `:free` in model names isn't mistaken for an effort level
- Allows empty model config so Codex falls back to `config.toml`

The patch is idempotent -- safe to run multiple times.

**3. Test**

```bash
codex exec "say hello"
```

### Usage with Humanize

```bash
# ask-codex: pass the full model name
/humanize:ask-codex --codex-model nvidia/nemotron-3-super-120b-a12b:free "your question"

# ask-codex: with explicit effort level (append after the model name)
/humanize:ask-codex --codex-model nvidia/nemotron-3-super-120b-a12b:free:medium "your question"

# RLCR loop: same syntax
/humanize:start-rlcr-loop plan.md --codex-model nvidia/nemotron-3-super-120b-a12b:free:high

# Or omit --codex-model entirely to use whatever is in config.toml
/humanize:ask-codex "your question"
```

### Tested Models

| Model | OpenRouter ID | Free |
|-------|---------------|------|
| Nemotron 120B | `nvidia/nemotron-3-super-120b-a12b:free` | Yes |
| DeepSeek R1 | `deepseek/deepseek-r1:free` | Yes |
| DeepSeek V3 | `deepseek/deepseek-chat-v3-0324:free` | Yes |
| Qwen3 235B | `qwen/qwen3-235b-a22b:free` | Yes |
| Qwen3 32B | `qwen/qwen3-32b:free` | Yes |
| Llama 4 Maverick | `meta-llama/llama-4-maverick:free` | Yes |
| Gemini 2.5 Pro | `google/gemini-2.5-pro-preview` | No |
| GPT-4o | `openai/gpt-4o` | No |

> **Note**: Free models may have rate limits and may not support all Codex features (e.g. tool calling). Test with `codex exec "say hello"` before starting an RLCR loop.

## Documentation

- [Usage Guide](docs/usage.md) -- Commands, options, environment variables
- [Install for Claude Code](docs/install-for-claude.md) -- Full installation instructions
- [Install for Codex](docs/install-for-codex.md) -- Codex skill runtime setup
- [Install for Kimi](docs/install-for-kimi.md) -- Kimi CLI skill setup
- [Configuration](docs/usage.md#configuration) -- Shared config hierarchy and override rules
- [Bitter Lesson Workflow](docs/bitlesson.md) -- Project memory, selector routing, and delta validation

## License

MIT
