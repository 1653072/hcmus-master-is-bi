---
name: learn-and-upgrade-hop-etl-skills
description: >-
  Capture new Hop ETL knowledge from the current conversation and upgrade project
  skills design-hop-etl and debug-hop-etl under .cursor/skills/, then sync to
  ~/.cursor/skills/. Use when the user invokes /learn-and-upgrade-hop-etl-skills,
  or when design-hop-etl or debug-hop-etl completes and may have discovered new
  patterns, pitfalls, or fixes worth persisting.
---

# Learn and Upgrade Hop ETL Skills

Maintain `.cursor/skills/design-hop-etl` and `.cursor/skills/debug-hop-etl` from **durable lessons** in the current conversation. Then sync all Hop skills to the developer's personal folder.

## When this skill runs

| Trigger | Action |
|---------|--------|
| User types `/learn-and-upgrade-hop-etl-skills` | Full review workflow below |
| End of `/design-hop-etl` or `/debug-hop-etl` (mandatory final step) | Same workflow — **skip if nothing meaningful** (see NOOP rules) |

## NOOP rules — do NOT update skills when

Stop immediately and tell the user **"No skill updates — nothing new to persist."** if ALL are true:

1. No new Hop-specific pitfall, XML pattern, config key, or symptom→fix mapping emerged.
2. No correction to **incorrect** content currently in `design-hop-etl` or `debug-hop-etl`.
3. The work was routine (e.g. re-run workflow, typo in unrelated file, user already knew the fix).
4. The lesson is one-off (specific machine path, single row of data, credentials).
5. The information already exists verbatim in the skills or `reference.md`.

**Do update** when the conversation revealed:

- A new recurring error and root cause (add to debug **Symptom → fix** table).
- A new pipeline/workflow pattern or anti-pattern (add to design **Pitfalls** or relevant pattern section).
- A corrected fact that was wrong in a skill (fix inaccurate lines).
- A new XML/template snippet worth reusing (add to `design-hop-etl/reference.md`).
- A new verify command or log path the team should reuse.

## Workflow

### Step 1 — Extract candidate knowledge

From the conversation (and any files changed this session), list bullet candidates:

- **Design:** patterns, pitfalls, config, load order, XML rules
- **Debug:** symptoms, exceptions, verify SQL, workflow mistakes

For each candidate, note: *one sentence lesson* + *target file* + *is it already in skills?*

If the list is empty after filtering NOOP rules → **stop (NOOP)**.

### Step 2 — Apply minimal edits (project skills only)

Edit files under **`.cursor/skills/`** in the repository — never `~/.cursor/skills-cursor/`.

| Knowledge type | Update |
|----------------|--------|
| New pitfall / design anti-pattern | `design-hop-etl/SKILL.md` → **Pitfalls** table (dedupe rows) |
| New XML/SQL template | `design-hop-etl/reference.md` (short snippet + comment) |
| New failure symptom | `debug-hop-etl/SKILL.md` → **Symptom → cause → fix** table |
| New debug command | `debug-hop-etl/SKILL.md` → relevant section |
| Wrong outdated skill text | Fix in place; do not duplicate |

**Editing rules:**

1. **Minimal diff** — one table row or a few lines, not a rewrite.
2. Keep `SKILL.md` files under ~500 lines; move long templates to `reference.md`.
3. **No secrets** — no passwords, API keys, or personal absolute paths.
4. Use generic paths: `3_Hop_ETL_Test/...`, `${PROJECT_HOME}`, not `/Users/...`.
5. Do not duplicate `3_Hop_ETL_Test/README.md` — link instead.

Optional: append a one-line entry to [learning-log.md](learning-log.md) with date + lesson (for team audit).

### Step 3 — Sync to personal skills

From **repository root**, run:

```bash
chmod +x .cursor/skills/sync-to-personal.sh
.cursor/skills/sync-to-personal.sh
```

This copies `design-hop-etl`, `debug-hop-etl`, and `learn-and-upgrade-hop-etl-skills` to `~/.cursor/skills/`.

If Step 2 made **no file changes**, **skip sync** and report NOOP.

### Step 4 — Report to user

**If updated:**

```markdown
## Skill upgrade summary
- **design-hop-etl:** [what changed or "unchanged"]
- **debug-hop-etl:** [what changed or "unchanged"]
- **reference.md / learning-log:** [if touched]
- **Personal sync:** completed via sync-to-personal.sh
- **Next:** commit `.cursor/skills/` and push so teammates get updates via git pull
```

**If NOOP:**

```markdown
No skill updates — nothing new to persist. Skills unchanged; sync not run.
```

## Integration with other skills

`design-hop-etl` and `debug-hop-etl` end with a **mandatory final step**: execute this skill's workflow with a short session summary. That step must respect NOOP rules — most sessions should not bloat the skills.

## Team workflow

1. Developer (or agent) upgrades skills in `.cursor/skills/`.
2. `sync-to-personal.sh` updates local `~/.cursor/skills/`.
3. **Commit and push** `.cursor/skills/` so the team receives updates via `git pull`.
4. Teammates run `sync-to-personal.sh` if they rely on personal copies.

Manual upgrade without a long chat:

```text
/learn-and-upgrade-hop-etl-skills
Session summary: [paste what you learned]
```

## Files

| Path | Role |
|------|------|
| `.cursor/skills/design-hop-etl/SKILL.md` | Design patterns & pitfalls |
| `.cursor/skills/design-hop-etl/reference.md` | XML/SQL templates |
| `.cursor/skills/debug-hop-etl/SKILL.md` | Symptom → fix & verify commands |
| `.cursor/skills/learn-and-upgrade-hop-etl-skills/learning-log.md` | Optional dated audit trail |
| `.cursor/skills/sync-to-personal.sh` | Project → personal copy |

## Additional resources

- Team guide: [../README.md](../README.md)
- Parent README: [../../README.md](../../README.md) section 2
