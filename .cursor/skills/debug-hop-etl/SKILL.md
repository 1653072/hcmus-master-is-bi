---
name: debug-hop-etl
description: >-
  Debug HCMUS BI Apache Hop ETL failures under 3_Hop_ETL_Test: workflow_logs,
  IllegalArgumentException, SAXParseException, connection errors, Mongo auth,
  batch_id and variable issues, MDM 401/404, staging row counts, Docker verify
  commands. Use when the user invokes /debug-hop-etl or reports a failed Hop
  pipeline, workflow, Web Service, or unexpected staging/NDS data.
---

# Debug Hop ETL (HCMUS Master IS BI)

## Debug workflow

1. **Identify scope:** pipeline only, workflow, or MDM Web Service?
2. **Read the log:** latest file in `3_Hop_ETL_Test/workflows/workflow_logs/` matching the failed action name.
3. **Note failing transform** and exact exception (first line + root cause).
4. **Match symptom** in the table below.
5. **Verify in DB/files** using commands in this skill.
6. If the fix requires new pipelines or refactors, switch to `/design-hop-etl`.

## Log locations

| Run type | Log path |
|----------|----------|
| Workflow action | `3_Hop_ETL_Test/workflows/workflow_logs/<action_name>_YYYYMMDD_HHMMSS.txt` |
| Hop GUI pipeline | Execution panel / Hop project log |
| Hop Server MDM | Server console + pipeline logs for `00_mdm_service_redirection` |

Workflow actions use `set_logfile=Y`, `logext=txt`, `add_date=Y`, `add_time=Y`.

## Symptom → cause → fix

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `IllegalArgumentException: Argument cannot be null` on TextFileInput2 | Empty `<files/>`, missing `<file><name>`, or empty `<fields>` | Add file block + field defs; see `design-hop-etl/reference.md` |
| `NullPointerException` in `TextFileInputMeta.getFields` / `Locale.of` | TextFileInput2 missing `<date_format_locale>` in generated XML | Add `<date_format_lenient>Y</date_format_lenient>` and `<date_format_locale>en_US</date_format_locale>` |
| TextFileInput2 `Single line found` on a valid CSV | Wrong line ending format, e.g. LF file configured as `DOS` | Inspect with `file` or byte counts; use `<format>UNIX</format>` for LF-only CSV and `DOS` for CRLF |
| `IllegalArgumentException: Argument cannot be null` | `${PROJECT_HOME}` or `STAGING_*_DIR` wrong | Update `development_configs.json` PROJECT_HOME (README script) |
| `SAXParseException` / cannot open `.hpl` | Malformed XML in `<order>` or unescaped `<` in SQL | Run `validate-hpl.sh`; fix hops; use `&lt;=` in SQL XML |
| Hop opens pipeline but read step has no files | Hop GUI stripped XML on save | Diff git; restore `<file>` and `<fields>`; add `validate-hpl.sh` to pre-commit |
| `batch_id` is NULL | Constant missing `<value>${STAGING_BATCH_ID}</value>` | Restore value + `use_formatting=Y` on Constant |
| `batch_id` is `INIT` | Load pipeline run standalone, not via workflow | Run `02_sub_workflow_load_exported_files_to_staging.hwf` (init runs first) |
| Different `batch_id` per table in same run | Init not run or parallel started before init finished | Check workflow hop: init → all loads; `wait_until_finished=Y` |
| `NumberFormatException` on Mongo get LSET | Formula transform with String type for dates | Use SQL `to_char()` in TableInput (see reference.md) |
| CHECK_DB_CONNECTIONS fails for Mongo | Mongo in RDBMS check list | Remove Mongo from CHECK_DB; add MQL `{"ping":1}` action |
| Mongo auth / SCRAM error | Wrong auth mechanism | `metadata/mongodb-connection/src-mongo-movies.json` → `SCRAM_SHA_256` |
| Export writes 0 rows | LSET/CET window has no data; control timestamps ahead of source | Query source `last_update_timestamp` range; reset control `lset`/`cet` in seed SQL if needed |
| Load inserts 0 rows | File missing or wrong `filemask` | `ls staging/exported_*`; match mask (`exported_movies.json` not `.jsonl`) |
| Type cast errors on load | CSV date format mismatch | SelectValues conversion_mask `yyyy/MM/dd HH:mm:ss.SSS` |
| PostgreSQL says numeric column received `character varying` from JsonInput | JsonInput emits numeric-looking JSON values as strings for this pipeline | Cast in ScriptValueMod or SelectValues before InsertUpdate/TableOutput |
| `NOT NULL` violation for GBFS `short_name` | Some station_information rows omit `short_name` | Fallback to `station_id` for staging key and flag those rows for join-quality review |
| Audit SQL cannot count staging rows while connected to control DB | `dw_staging` and `dw_control` are separate databases, not schemas in one DB | Use a separate audit pipeline: TableInput on `dw-staging` for counts, then InsertUpdate/TableOutput on `dw-control` |
| TableOutput connection error | Docker down or wrong port | `docker-compose ps`; test `dw-staging` on 5434 |
| MDM HTML `401 Unauthorized` | Hop Server Basic Auth failed | `cluster`/`cluster`; curl `-u cluster:cluster` |
| MDM JSON `401 Unauthorized` | Wrong or missing `X-API-Key` | Header must match `HOP_MDM_USERS_API_KEY`; entry pipeline accepts case-insensitive `x-api-key` |
| `connection refused` on `:8080` | Hop Server not running | Start `hop-server.sh -e "Hop_ETL_Test_Configs" -j HCMUS_Master_IS_BI_Hop_ETL_Test 127.0.0.1 8080` |
| `go run push_mdm_user.go` fails | Single-file run skips `main.go` | `cd 3_Hop_ETL_Test/backend && go run .` |
| Hop Server up but variables null | Wrong `-e` lifecycle environment | Use `Hop_ETL_Test_Configs`, not `HOP_ENV` from `development_configs.json` |
| MDM HTTP 200 but no `stg_users` row | Storage pipeline error or NDS lookup | Check Hop Server console; query `staging.stg_users`; verify Docker `dw-staging` on 5434 |
| MDM `404` on DELETE | User not in `nds.users` | Expected per reconcile rules; or seed NDS first |
| Web Service returns multiple responses | Row Generator limit > 1 | Set limit to **1** in entry pipeline |
| Pipeline variable not resolved | Missing `use_formatting=Y` or wrong scope | SetVariable/Constant need formatting; use PARENT_WORKFLOW in workflow context |

## Validate .hpl XML

From repo root:

```bash
.cursor/skills/design-hop-etl/scripts/validate-hpl.sh 3_Hop_ETL_Test/pipelines/06_Load_Exported_Files_To_Staging/01_load_exported_ratings_to_staging.hpl
```

Or batch all changed pipelines:

```bash
find 3_Hop_ETL_Test/pipelines -name '*.hpl' -exec .cursor/skills/design-hop-etl/scripts/validate-hpl.sh {} \;
```

## Docker health

```bash
cd 3_Hop_ETL_Test/docker
docker-compose ps
docker-compose logs --tail=50 <service_name>
```

Reset data (schema changed):

```bash
docker-compose down -v && docker-compose up -d
```

## Verify source data

```bash
# PostgreSQL ratings
docker exec hcmus-master-is-bi-db-src-ratings-revenues \
  psql -U hop_reader -d ratings_revenues -c "SELECT COUNT(*) FROM ratings;"

# Mongo movies
docker exec hcmus-master-is-bi-db-src-mongo \
  mongosh -u hop_reader -p hop_reader --authenticationDatabase movielens_auth movielens_data \
  --eval "db.movies.countDocuments()"
```

## Verify control table

```bash
docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_control -d dw_control \
  -c "SELECT control_id, source_name, table_name, lset, cet, last_run_status, rows_extracted FROM control.etl_extraction_control ORDER BY control_id;"
```

## Verify staging load

```bash
docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_staging -d dw_staging -c "
SELECT 'stg_ratings' AS t, COUNT(*) AS rows, COUNT(DISTINCT batch_id) AS batches FROM staging.stg_ratings
UNION ALL SELECT 'stg_revenues', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_revenues
UNION ALL SELECT 'stg_movies', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_movies
UNION ALL SELECT 'stg_genres', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_genres
UNION ALL SELECT 'stg_persons', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_persons
UNION ALL SELECT 'stg_users', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_users;"
```

**Expected (pull path):** one `batch_id` value shared across ratings/revenues/movies/genres/persons after a single load workflow run.

## Verify exported files

```bash
ls -la 3_Hop_ETL_Test/staging/exported_ratings/
head -3 3_Hop_ETL_Test/staging/exported_ratings/exported_ratings.csv
head -1 3_Hop_ETL_Test/staging/exported_movies/exported_movies.json
```

## MDM push smoke test

**Checklist before push:**

1. `docker-compose ps` — `dw-stg-postgres` healthy on 5434
2. Hop Server running with `-e "Hop_ETL_Test_Configs"` (lifecycle name)
3. `PROJECT_HOME` in `development_configs.json` points at `3_Hop_ETL_Test`

```bash
# Hop Server must be running on 8080
cd 3_Hop_ETL_Test/backend && go run .

docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_staging -d dw_staging \
  -c "SELECT user_id, username, operation, batch_id, loaded_at FROM staging.stg_users ORDER BY loaded_at DESC LIMIT 5;"
```

## Variable debugging

In Hop GUI or log, confirm resolved values for the failing run:

| Variable | Set by | Expected when |
|----------|--------|---------------|
| `PROJECT_HOME` | `development_configs.json` | Absolute path to `3_Hop_ETL_Test` |
| `STAGING_BATCH_ID` | `00_init_staging_batch_id` | Timestamp string after init |
| `RATING_LSET` / `RATING_CET` | `01_get_stg_ratings_lset_cet` | From control table |
| `HOP_MDM_USERS_API_KEY` | config | Matches Go/curl header |

If running a **single pipeline** in GUI, workflow variables from SetVariable (`PARENT_WORKFLOW`) are **not** set — use workflow run or accept config defaults.

## Common workflow mistakes

| Mistake | Result |
|---------|--------|
| Run `01_load_*` without export sub-workflow | Empty or stale files |
| Skip `00_init` when testing loads | `batch_id = INIT` |
| Parallel export before Mongo ping passes | Cascading failures |
| Edit `.hpl` in GUI without git diff | Silent XML corruption |

## Escalation checklist

Before asking for help, collect:

- [ ] Failing file path (`.hpl` / `.hwf`)
- [ ] Transform name from log
- [ ] Full exception + root cause
- [ ] Run via workflow or single pipeline?
- [ ] `validate-hpl.sh` output
- [ ] Relevant row counts / `batch_id` query output

## Related

- Design patterns & fixes: `/design-hop-etl`
- Project README: `3_Hop_ETL_Test/README.md`
- Sync skills locally: `.cursor/skills/sync-to-personal.sh`

## Final step — learn and upgrade (mandatory)

After the main debug task is complete (fix applied or root cause identified):

1. Read and follow [`.cursor/skills/learn-and-upgrade-hop-etl-skills/SKILL.md`](../learn-and-upgrade-hop-etl-skills/SKILL.md) (same as `/learn-and-upgrade-hop-etl-skills`).
2. Pass a short **session summary**: exception, root cause, fix, any new symptom→fix mapping.
3. Apply **NOOP rules** in that skill — if the issue was already documented or was a one-off, report *"No skill updates"* and **do not** edit skills or run sync.
4. If skills were updated, run `.cursor/skills/sync-to-personal.sh` from the repository root (the learn skill does this).

Do not skip this step silently; always state whether skills were upgraded or NOOP.
