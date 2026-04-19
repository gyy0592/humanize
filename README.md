# Humanize

**Current Version: 1.16.0**

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
# Add PolyArch marketplace
/plugin marketplace add PolyArch/humanize
# If you want to use development branch for experimental features
/plugin marketplace add PolyArch/humanize#dev
# Then install humanize plugin
/plugin install humanize@PolyArch
```

Requires [codex CLI](https://github.com/openai/codex) for review, or use `--reviewer claude` to review with a fresh Claude instance instead. See the full [Installation Guide](docs/install-for-claude.md) for prerequisites and alternative setup options.

## Quick Start

1. **Generate a plan** from your draft:
   ```bash
   /humanize:gen-plan --input draft.md --output docs/plan.md
   ```

2. **Refine an annotated plan** before implementation when reviewers add comments (`CMT:` ... `ENDCMT`, `<cmt>` ... `</cmt>`, or `<comment>` ... `</comment>`):
   ```bash
   /humanize:refine-plan --input docs/plan.md
   ```

3. **Run the loop**:
   ```bash
   /humanize:start-rlcr-loop docs/plan.md
   ```

4. **Use Claude as reviewer** (no Codex required):
   ```bash
   /humanize:start-rlcr-loop docs/plan.md --reviewer claude
   # Pick a model (sonnet, haiku, opus; default: sonnet)
   /humanize:start-rlcr-loop docs/plan.md --reviewer claude --claude-model opus
   ```

5. **Consult Gemini** for deep web research (requires Gemini CLI):
   ```bash
   /humanize:ask-gemini What are the latest best practices for X?
   ```

6. **Monitor progress (in another terminal, not inside Claude Code)**:
   ```bash
   source <path/to/humanize>/scripts/humanize.sh # Or just add it into your .bashec or .zshrc
   humanize monitor rlcr       # RLCR loop
   humanize monitor skill      # All skill invocations (codex + gemini)
   humanize monitor codex      # Codex invocations only
   humanize monitor gemini     # Gemini invocations only
   ```

## Keeping Updated (Fork Maintenance)

This fork maintains Claude functionality while staying current with upstream improvements:

### **Branch Structure**
- `claude-pure` - Pure Claude features only (stable feature branch)
- `claude-latest` - Claude features + latest upstream (daily use branch)

### **Update Workflow**
```bash
# When PolyArch/humanize dev has new features:
cd ~/Programs/humanize
git fetch upstream dev

# Update daily-use branch (keeps Claude features + latest upstream)
git checkout claude-latest
git rebase upstream/dev
# Resolve conflicts if needed, then:
git push origin claude-latest --force-with-lease

# claude-pure branch stays unchanged (pure Claude features only)
```

### **Installation**
```bash
# Local installation (recommended for development):
/plugin marketplace add /path/to/humanize
/plugin install humanize@PolyArch

# Make sure you're on claude-latest branch for daily use
```

## Monitor Dashboard

<p align="center">
  <img src="docs/images/monitor.png" alt="Humanize Monitor" width="680"/>
</p>

## Documentation

- [Usage Guide](docs/usage.md) -- Commands, options, environment variables
- [Install for Claude Code](docs/install-for-claude.md) -- Full installation instructions
- [Install for Codex](docs/install-for-codex.md) -- Codex skill runtime setup
- [Install for Kimi](docs/install-for-kimi.md) -- Kimi CLI skill setup
- [Configuration](docs/usage.md#configuration) -- Shared config hierarchy and override rules
- [Bitter Lesson Workflow](docs/bitlesson.md) -- Project memory, selector routing, and delta validation

## License

MIT
