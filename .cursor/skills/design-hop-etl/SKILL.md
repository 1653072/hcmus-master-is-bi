---
name: design-hop-etl
description: >-
  Design and implement HCMUS BI Apache Hop ETL under 3_Hop_ETL_Test: architecture,
  development_configs.json, Docker topology, incremental LSET/CET export pipelines,
  staging file loads, workflows, MDM Web Service push, NDS/DDS load patterns,
  connection metadata, and .hpl/.hwf XML conventions. Use when the user invokes
  /design-hop-etl or asks to create, extend, or refactor Hop pipelines, workflows,
  staging, control tables, NDS, DDS, or MDM integration.
---

# Design Hop ETL (HCMUS Master IS BI)

## Quick start

1. Read `3_Hop_ETL_Test/README.md` and `2_Guidelines/README.md` for assignment rules.
2. Copy patterns from **existing** pipelines in the same numbered folder — do not invent new structure.
3. After editing any `.hpl`, run `.cursor/skills/design-hop-etl/scripts/validate-hpl.sh <file>`.
4. For failures, switch to `/debug-hop-etl`.

## Project layout

```
hcmus-master-is-bi/
├── 2_Guidelines/README.md          # DW assignment requirements (3NF, SCD, LSET/CET, MDM)
├── 3_Hop_ETL_Test/
│   ├── development_configs.json    # Single source of truth for ${VARIABLES}
│   ├── metadata/rdbms/             # dw-staging, dw-control, dw-nds, dw-dds, sources
│   ├── metadata/mongodb-connection/
│   ├── metadata/web-service/         # mdm-users.json
│   ├── docker/                     # docker-compose, schema seed SQL
│   ├── staging/exported_*/         # CSV/JSON landing zone (pull path)
│   ├── pipelines/
│   │   ├── 01_Export_Ratings_Source_To_CSV/     # 01_get, 02_extract, 03_update
│   │   ├── 02_Export_Revenues_Source_To_CSV/
│   │   ├── 03_Export_Movies_Source_To_JSON/
│   │   ├── 04_Export_Genres_Source_To_JSON/
│   │   ├── 05_Export_Persons_Source_To_JSON/
│   │   ├── 06_Load_Exported_Files_To_Staging/   # 00_init + 01..05 loads
│   │   ├── 07_Transform_And_Load_Staging_To_NDS/
│   │   ├── 08_Transform_And_Load_NDS_To_DDS/
│   │   └── 09_Push_MDM_Users_To_ETL_Hop/        # Web Service entry + storage
│   ├── workflows/
│   │   ├── 00_master_staging_etl_workflow.hwf
│   │   ├── 01_sub_workflow_export_all_data_sources_to_files.hwf
│   │   └── 02_sub_workflow_load_exported_files_to_staging.hwf
│   └── backend/                    # Go MDM push demo
└── .cursor/skills/                 # design-hop-etl, debug-hop-etl (this repo)
```

## Architecture

### Hybrid extract (assignment requirement)

| Path | Sources | Mechanism | Hop area |
|------|---------|-----------|----------|
| **Pull** | Ratings, Revenues (PG), Movies/Genres/Persons (Mongo) | LSET/CET incremental → files → staging | `01`–`06` |
| **Push** | Users (master data) | HTTP Web Service → `stg_users` | `09` + Go backend |

### Layer flow

```
Sources → staging/exported_* (files) → dw_staging.staging.*
       → dw_nds.nds.* (3NF) → dw_dds.* (star schema, Power BI)
```

Control/metadata on port **5434** as **separate databases**: `dw_staging`, `dw_control`, `dw_metadata`.

## Docker & connections

| Role | Host | Port | Database | User |
|------|------|------|----------|------|
| Ratings/Revenues source | localhost | 5432 | ratings_revenues | hop_reader |
| Users source | localhost | 5433 | users | hop_reader |
| Staging + control + metadata | localhost | 5434 | dw_staging / dw_control / dw_metadata | hop_staging / hop_control / hop_metadata |
| NDS | localhost | 5435 | dw_nds | hop_nds |
| DDS | localhost | 5436 | dw_dds | hop_dds |
| Mongo | localhost | 27017 | movielens_data | hop_reader (authSource: movielens_auth) |
| Hop Server (MDM) | 127.0.0.1 | 8080 | — | cluster / cluster (Basic Auth) |

Connection JSON lives in `3_Hop_ETL_Test/metadata/`. Mongo must use `authenticationMechanism: SCRAM_SHA_256`.

**Setup:** `cd 3_Hop_ETL_Test/docker && docker-compose up -d`. Set `PROJECT_HOME` in `development_configs.json` (see README).

## Configuration (`development_configs.json`)

- **Never hardcode** paths or credentials in pipelines — use `${VAR}` from this file.
- Key groups: `PROJECT_HOME`, `STAGING_*_DIR`, `STAGING_BATCH_ID`, `*_DB_*`, `MONGO_*`, `HOP_MDM_*`.
- `STAGING_BATCH_ID` default `INIT` is a fallback; runtime value comes from `00_init_staging_batch_id.hpl`.

When adding a new source, add variables here first, then wire connections and pipelines.

## Pipeline numbering convention

| Folder | Purpose |
|--------|---------|
| `01`–`05` | Export source → file (3 pipelines each) |
| `06` | Load file → `dw_staging` |
| `07` | Transform + load staging → NDS (3NF, upsert, load order) |
| `08` | NDS → DDS (dimensions before facts, SCD) |
| `09` | MDM push (Web Service) |

Each export folder standard names:
- `01_get_stg_<entity>_lset_cet.hpl`
- `02_extract_stg_<entity>_to_csv|jsonl.hpl`
- `03_update_stg_<entity>_lset_cet.hpl`

## Pattern A — Incremental export (LSET/CET)

Reference: `pipelines/01_Export_Ratings_Source_To_CSV/`.

### Control table (`control.etl_extraction_control`)

Tracks `lset`, `cet`, `rows_extracted`, `last_run_status` per source (`control_id` 1–5 for ratings, revenues, movies, genres, persons).

### Pipeline 01 — get LSET/CET

- `TableInput` on `dw_control` → read `lset`, `cet` for this `control_id`
- `SetVariable` → `PARENT_WORKFLOW` (e.g. `RATING_LSET`, `RATING_CET`)
- Mongo sources: also set `*_LSET_ISO`, `*_CET_ISO` via SQL `to_char()` — **not** Formula with `value_type: String` (causes NumberFormatException)

### Pipeline 02 — extract

- **PostgreSQL:** `TableInput` with `WHERE last_update_timestamp > '${LSET}'::timestamp AND last_update_timestamp <= '${CET}'::timestamp`
- **Mongo:** `MongoDbInput` with JSON query using ISO date variables
- `TextFileOutput` → `${STAGING_*_DIR}/exported_<entity>` (extension csv or json)
- Parallel branch: `COUNT(*)` → `SetVariable` `*_ROWS_EXTRACTED` on `PARENT_WORKFLOW`

### Pipeline 03 — update control

- `ExecSQL` with `replace_variables=Y` to set new `lset = cet`, status, `rows_extracted`

### Workflow checks

- `CHECK_DB_CONNECTIONS` for RDBMS only
- Mongo: separate **MQL** action `{"ping":1}` — do not add Mongo to CHECK_DB_CONNECTIONS

## Pattern B — Staging load from files (`06`)

Reference: `pipelines/06_Load_Exported_Files_To_Staging/`.

### Workflow order (`02_sub_workflow_load_exported_files_to_staging.hwf`)

1. `CHECK_DB_CONNECTIONS` (dw-staging)
2. `00_init_staging_batch_id.hpl` — sets `STAGING_BATCH_ID` on `PARENT_WORKFLOW`
3. Parallel: `01`–`05` load pipelines (`pass_all_parameters=Y`)

### Init batch id (`00_init_staging_batch_id.hpl`)

```
SystemInfo (system date) → SetVariable STAGING_BATCH_ID (PARENT_WORKFLOW, use_formatting=Y)
```

### Load transform chain (per entity)

| Step | CSV | JSONL |
|------|-----|-------|
| Read | TextFileInput2 (header Y, fields explicit) | TextFileInput2 (separator `$[01]`, field `json_line`) |
| Parse | — | JsonInput (JSONPath, removeSourceField Y) |
| Clean | StringOperations trim | trim + ReplaceString for movies genres array |
| Cast | SelectValues meta types | SelectValues |
| Batch | Constant `batch_id` = `${STAGING_BATCH_ID}`, **use_formatting=Y** | same |
| Write | TableOutput → `staging.stg_*`, connection `dw-staging` | same |

XML templates: [reference.md](reference.md).

### Staging tables

Defined in `docker/dw-stg-postgres/02_staging_schema.sql`. No heavy indexes/constraints in staging (assignment rule).

## Pattern C — Workflows (`.hwf`)

- Master: `00_master_staging_etl_workflow` → export sub-WF then load sub-WF
- Export sub-WF: check DB + Mongo → **parallel** export branches per source
- Load sub-WF: check DB → init batch → **parallel** loads
- Pipeline actions: `wait_until_finished=Y`, `pass_all_parameters=Y`, logs under `workflows/workflow_logs/`
- Use `parallel=Y` only when branches are independent

### Variable scopes

| Scope | When to use |
|-------|-------------|
| `PARENT_WORKFLOW` | LSET/CET, row counts, `STAGING_BATCH_ID` shared across pipelines in same sub-workflow |
| Config default | Fallback when running a single pipeline in GUI without workflow |
| `ROOT_WORKFLOW` | Only if variable must survive nested sub-workflow boundaries |

## Pattern D — MDM push (`09`)

Reference: `3_Hop_ETL_Test/README.md` section "How to push MDM data".

### Web Service metadata (`metadata/web-service/mdm-users.json`)

| Field | Value | Role |
|-------|-------|------|
| `name` | `mdm-users` | Must match `?service=mdm-users` and `HOP_MDM_USERS_SERVICE_ID` |
| `filename` | `00_mdm_service_redirection.hpl` | Entry pipeline only |
| `bodyContentVariable` | `MDM_REQUEST_BODY` | POST JSON body injected by Hop servlet |
| `headerContentVariable` | `MDM_REQUEST_HEADERS` | Request headers as JSON string |
| `transformName` / `fieldName` | `Build JSON response` / `response_json` | HTTP response from entry pipeline |

Go demo (`backend/push_mdm_user.go`) reads this file to assert `name` matches before POST.

### Two pipelines

1. `00_mdm_service_redirection.hpl` — Row Generator limit **1** → GetVariable (`MDM_REQUEST_BODY`, `MDM_REQUEST_HEADERS`, `HOP_MDM_USERS_API_KEY`) → **ScriptValueMod** (case-insensitive `X-API-Key` parse) → FilterRows → Pipeline Executor or 401 JSON
2. `01_store_pushed_mdm_user_from_backend_to_staging.hpl` — GetVariable `MDM_REQUEST_BODY` → JsonInput → validate → reconcile vs `nds.users` → upsert `staging.stg_users`

`?service=mdm-users` is enforced by the Hop servlet (not inside the pipeline).

### Auth (two layers — both required)

1. Hop Server **Basic Auth** (servlet): `cluster` / `cluster` — set via `req.SetBasicAuth` in Go or `curl -u cluster:cluster`
2. Pipeline **X-API-Key** (application): header must match `${HOP_MDM_USERS_API_KEY}` (default `local-dev-mdm-key`)

### Operation reconcile

| Backend operation | User in NDS? | Stored operation |
|-------------------|--------------|------------------|
| INSERT | No | INSERT |
| INSERT | Yes | UPDATE |
| UPDATE | Yes | UPDATE |
| UPDATE | No | INSERT |
| DELETE | Yes | DELETE |
| DELETE | No | HTTP 404 |

`batch_id` for MDM: `{service_id}-{user_id}-{loaded_at}` — different from pull-path `STAGING_BATCH_ID`.

### Hop Server start

Use the **lifecycle environment name** from Hop GUI / `hop-config.json` — **not** the `HOP_ENV` variable inside `development_configs.json`:

```bash
./hop-server.sh \
  -e "Hop_ETL_Test_Configs" \
  -j HCMUS_Master_IS_BI_Hop_ETL_Test \
  127.0.0.1 8080
```

Host and port are **positional** at the end; `-p` is **password**, not port. Optional: `-u cluster -p cluster`.

**Prerequisites:** Docker up (`dw_staging` on 5434), `PROJECT_HOME` set in `development_configs.json`.

**Test push** (compile whole Go package, not a single file):

```bash
cd 3_Hop_ETL_Test/backend && go run .
```

Backend POST URL: `http://127.0.0.1:8080/hop/webService/?service=mdm-users` with Basic Auth + `X-API-Key`.

## Pattern E — Staging → NDS (`07`, to implement)

Guidelines (`2_Guidelines/README.md`):

- **3NF**, upsert on natural keys
- **Load order:** master/reference before transactions  
  Suggested: users (from `stg_users` MDM) → persons → genres → movies → revenues → ratings
- **Late-arriving dimensions:** rating with unknown `user_id` → hold in staging or skeleton row in `nds.users` until MDM push arrives
- Log jobs in `control.etl_job_log`
- Row-count reconciliation vs staging batch

NDS schema starter: `docker/dw-nds-postgres/02_nds_schema.sql` (extend as needed).

## Pattern F — NDS → DDS (`08`, to implement)

- Star/snowflake schema; define **fact grain** explicitly
- **Dimensions before facts**; surrogate key lookups when loading facts
- **SCD:** Type 1 overwrite vs Type 2 history — document per dimension
- Power BI reads `dw_dds` on port 5436 (`analytics_reader`)
- Mapping document: source column → staging → NDS → DDS (grading requirement)

## .hpl XML rules (critical)

1. **TextFileInput2** must have `<file><name>`, `<filemask>`, and explicit `<fields>` — never empty `<files/>`.
2. **Constant** for variables: `<value>${VAR}</value>` + `<use_formatting>Y</use_formatting>`.
3. **SQL in TableInput:** escape `<` as `&lt;` in XML.
4. Validate with `scripts/validate-hpl.sh` before committing.
5. After Hop GUI save, **diff XML** — GUI may strip `<value>`, `<file>`, or `<fields>`.

Full XML snippets: [reference.md](reference.md).

## Implementation checklist (new pipeline)

```
- [ ] Variables added to development_configs.json
- [ ] Connection metadata JSON if new DB
- [ ] Control row in etl_extraction_control (if incremental pull)
- [ ] Pipeline follows folder numbering and naming
- [ ] Copied transform pattern from reference pipeline in same category
- [ ] Workflow hop added with pass_all_parameters=Y
- [ ] validate-hpl.sh passes on all new/changed .hpl
- [ ] README or workflow_logs verify steps documented if new entity
```

## Pitfalls (project-specific)

| Mistake | Consequence |
|---------|-------------|
| Empty TextFileInput2 file/fields | `IllegalArgumentException: Argument cannot be null` |
| TextFileInput2 missing date locale | Runtime `NullPointerException` in `Locale.of` | Include `date_format_lenient` + `date_format_locale` even when reading fields as strings |
| Wrong CSV line format | `Single line found` on LF/CRLF mismatch | Match `<format>` to source files: `UNIX` for LF, `DOS` for CRLF |
| Counting staging rows from control SQL | Cross-database query failure or misleading audit | Read counts from `dw-staging`, then write audit rows to `dw-control` in a separate step |
| JsonInput numeric values passed straight to DB | PostgreSQL type errors | Cast JSON numeric fields before `InsertUpdate` |
| Malformed `<order>` XML (e.g. join on string in generators) | SAXParseException, Hop cannot open file |
| Constant without use_formatting | Literal `${STAGING_BATCH_ID}` or null batch_id |
| Run load pipeline without init workflow | batch_id stays `INIT` |
| Formula for Mongo ISO dates | NumberFormatException |
| Mongo in CHECK_DB_CONNECTIONS | False connection failures |
| Wrong MDM URL param | Use `?service=mdm-users`, not `service_id` |
| `go run push_mdm_user.go` only | Package has `main.go` + `push_mdm_user.go` | Run `go run .` from `3_Hop_ETL_Test/backend/` |
| Wrong Hop Server `-e` name | `HOP_ENV=dev` ≠ lifecycle env | Use `-e "Hop_ETL_Test_Configs"` (Hop GUI environment name) |
| Hop Server not started | Connection refused on 8080 | Start `hop-server.sh` before Go push or curl |
| Basic Auth only (no API key) | Passes servlet but pipeline 401 | Send **both** `-u cluster:cluster` and `X-API-Key` header |
| File-source CET = `MAX(raw_loaded_at)` | Watermark jumps to wall-clock; next LSET skips all historical CSV rows | For file pulls, filter on business ts (`started_at` / `observation_ts`); set `CET_*=CLOCK_TIMESTAMP()` at start and advance `control.lset/cet` to that CET |
| Filter file→raw on business event time | Late-arriving rows with old `started_at` / `observation_ts` disappear before DQ and staging | Keep the full delivered file in raw; apply `[LSET - LookbackDays, CET]` only in the accepted raw→staging stream |
| Advance watermark to effective lookback LSET | Watermark moves backward and repeatedly widens the extract | Commit `control.lset/cet` to the run CET; Lookback only widens the read window |
| Parallel source branches set the same JVM lookback variable | Last-writer-wins race makes the runtime window nondeterministic | Prefer per-source JVM vars (`LOOKBACK_DAYS_DIVVY_TRIPS`, `LOOKBACK_DAYS_CITIBIKE_TRIPS`, `LOOKBACK_DAYS_NOAA`) set from each watermark branch; never share one lookback var across parallel writers |

## Additional resources

- XML templates & reconcile table: [reference.md](reference.md)
- Troubleshooting: use `/debug-hop-etl` skill
- Sync skills to personal Cursor: `.cursor/skills/sync-to-personal.sh`
- Team guide: [.cursor/skills/README.md](../README.md)

## Final step — learn and upgrade (mandatory)

After the main design task is complete and `validate-hpl.sh` has passed on changed `.hpl` files:

1. Read and follow [`.cursor/skills/learn-and-upgrade-hop-etl-skills/SKILL.md`](../learn-and-upgrade-hop-etl-skills/SKILL.md) (same as `/learn-and-upgrade-hop-etl-skills`).
2. Pass a short **session summary**: what was built/changed, any new pitfalls, XML patterns, or config lessons.
3. Apply **NOOP rules** in that skill — if nothing meaningful is new, report *"No skill updates"* and **do not** edit skills or run sync.
4. If skills were updated, run `.cursor/skills/sync-to-personal.sh` from the repository root (the learn skill does this).

Do not skip this step silently; always state whether skills were upgraded or NOOP.
