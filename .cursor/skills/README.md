# Cursor Agent Skills — HCMUS BI Hop ETL

Project-level skills for designing, debugging, and **continuously improving** Apache Hop ETL in this repository. Commit and push so the whole team shares the same agent context.

## Skills

| Invoke in chat | Folder | Purpose |
|----------------|--------|---------|
| `/design-hop-etl` | [design-hop-etl/](design-hop-etl/) | Architecture, pipelines, workflows, MDM, NDS/DDS patterns, XML conventions |
| `/debug-hop-etl` | [debug-hop-etl/](debug-hop-etl/) | Failure diagnosis, logs, verify SQL, symptom → fix |
| `/learn-and-upgrade-hop-etl-skills` | [learn-and-upgrade-hop-etl-skills/](learn-and-upgrade-hop-etl-skills/) | Persist new lessons into design/debug skills; sync to personal folder |

**Flow:** `/design-hop-etl` and `/debug-hop-etl` end with a mandatory step that runs the learn skill (NOOP when nothing new).

Detailed XML templates: [design-hop-etl/reference.md](design-hop-etl/reference.md)

## Team setup (project skills — automatic)

1. Clone/pull this repository.
2. Open the repo root in **Cursor**.
3. Project skills under `.cursor/skills/` are available to the agent in this workspace.

No extra install step for project-level use.

## Personal skills (optional — same content on all your machines)

Copy project skills to `~/.cursor/skills/` so they work in **any** Cursor workspace (or when the agent prefers personal skill paths).

From **repository root**:

```bash
chmod +x .cursor/skills/sync-to-personal.sh
.cursor/skills/sync-to-personal.sh
```

Re-run after every `git pull` that updates `.cursor/skills/`.

The learn skill runs this script automatically **after** it updates project skills. If it NOOPs, sync is skipped.

**Do not** edit only the personal copy — change skills in this repo, push, then re-sync.

## Validate pipeline XML

```bash
chmod +x .cursor/skills/design-hop-etl/scripts/validate-hpl.sh

.cursor/skills/design-hop-etl/scripts/validate-hpl.sh \
  3_Hop_ETL_Test/pipelines/06_Load_Exported_Files_To_Staging/01_load_exported_ratings_to_staging.hpl
```

## Upgrading skills (maintainers)

**Preferred:** let `/learn-and-upgrade-hop-etl-skills` capture lessons after design/debug sessions.

**Manual:**

1. Edit `SKILL.md` or `reference.md` in the relevant folder.
2. Keep each `SKILL.md` under ~500 lines; move long templates to `reference.md`.
3. Update the **Pitfalls** or **Symptom → fix** section when you fix a new class of bug.
4. Run `validate-hpl.sh` on any example `.hpl` you change.
5. Run `sync-to-personal.sh`, then commit, push; tell team to `git pull` and re-sync.

Optional audit: [learn-and-upgrade-hop-etl-skills/learning-log.md](learn-and-upgrade-hop-etl-skills/learning-log.md)

## What not to put in skills

- Full duplicate of `3_Hop_ETL_Test/README.md` — link to it instead.
- Secrets or production credentials.
- Files under `~/.cursor/skills-cursor/` (Cursor internal — never write there).

## Related docs

- [3_Hop_ETL_Test/README.md](../../3_Hop_ETL_Test/README.md) — Docker, MDM, connections
- [2_Guidelines/README.md](../../2_Guidelines/README.md) — assignment requirements
- [../../README.md](../../README.md) — parent README (skills + Hop setup)
