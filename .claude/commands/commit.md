---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*)
description: Create a git commit following project conventions
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Create a git commit following these rules:

1. **Commit message format:**
   - Short imperative description, no ticket prefix (personal hackathon repo)
   - Keep subject line under 72 characters
   - Do NOT add "Co-Authored-By" or any AI attribution
   - Focus on the "why" not the "what"

2. **Execution:**
   - Stage files and create commit in a single message
   - Use `git commit -m` with the message
   - Do not send any other text besides the tool calls
