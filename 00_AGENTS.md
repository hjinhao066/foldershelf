# Agent Rules

You are participating in a human-coordinated multi-agent project to fix bugs and improve FolderShelf (a macOS top-edge hover-triggered folder popup utility). The human coordinator (Boss / 老大) is the final decision maker.

## Must Read First

Read these before working:

1. `01_BRIEF.md`
2. `02_STATUS.md`
3. `03_FACTS.md`
4. `04_DECISIONS.md`
5. `05_TASKS.md`

## Source Of Truth

These files are human-owned unless the coordinator explicitly says otherwise:

- `01_BRIEF.md`
- `02_STATUS.md`
- `03_FACTS.md`
- `04_DECISIONS.md`
- `05_TASKS.md`

## Write Permission

You may edit only:

- your own `agent_<name>.md`
- your own `working/<name>/`

Do not edit:

- another agent's files
- `raw/` (contains read-only copy of the source code)
- `final/`
- source-of-truth files
- `/Users/jinhao/FolderShelf/App.swift` (unless you are explicitly assigned as the merge agent)

Exception: edit `final/` or source-of-truth files only when the coordinator explicitly assigns you to merge or update them.

## Competition Rule

If multiple agents do the same task, create your own candidate under `working/<name>/`. Do not overwrite shared or final files.

## Required Log Format

Append this to your agent file after each run:

```md
## Run: <timestamp>

### Task Understood
- ...

### Actions Taken
- ...

### Files Created Or Edited
- ...

### Findings
- ...

### Recommended Coordinator Decision
- ...

### Open Questions
- ...
```
