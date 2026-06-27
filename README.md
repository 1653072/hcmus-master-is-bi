# HCMUS Master IS — Advanced Business Intelligence

Data Warehouse final project: hybrid ETL (Apache Hop), Docker fake data sources, staging → NDS → DDS, and MDM push integration.

## Table of Contents

1. [Repository overview](#1-repository-overview)
2. [Part 1 — Cursor AI skills (project & personal)](#2-part-1--cursor-ai-skills-project--personal)
   1. [What are project skills?](#21-what-are-project-skills)
   2. [Skill structure in this repo](#22-skill-structure-in-this-repo)
   3. [How to use skills in Cursor (project level)](#23-how-to-use-skills-in-cursor-project-level)
   4. [How to sync project skills to personal skills](#24-how-to-sync-project-skills-to-personal-skills)
   5. [How to maintain and upgrade skills (team)](#25-how-to-maintain-and-upgrade-skills-team)
   6. [Using skills with AI assistants — quick prompts](#26-using-skills-with-ai-assistants--quick-prompts)
   7. [Pipeline XML validation (`validate-hpl.sh`)](#27-pipeline-xml-validation-validate-hplsh)
   8. [Learn and upgrade skills (`/learn-and-upgrade-hop-etl-skills`)](#28-learn-and-upgrade-skills-learn-and-upgrade-hop-etl-skills)
3. [Part 2 — Hop ETL Test (`3_Hop_ETL_Test`)](#3-part-2--hop-etl-test-3_hop_etl_test)
   1. [Prerequisites and tool installation](#31-prerequisites-and-tool-installation)
   2. [First-time project setup](#32-first-time-project-setup)
   3. [Docker Compose — start, stop, reset](#33-docker-compose--start-stop-reset)
   4. [Run Apache Hop GUI](#34-run-apache-hop-gui)
   5. [Run Apache Hop Server (MDM Web Service)](#35-run-apache-hop-server-mdm-web-service)
   6. [Run ETL workflows (GUI)](#36-run-etl-workflows-gui)
   7. [Where to read more](#37-where-to-read-more)
4. [Part 3 — Official Hop Project (`4_Official_Hop_Project`)](#4-part-3--official-hop-project-4_official_hop_project)
5. [Related documentation](#5-related-documentation)

---

## 1. Repository overview

| Folder | Purpose |
|--------|---------|
| [`2_Guidelines/`](2_Guidelines/README.md) | Assignment requirements (3NF, SCD, LSET/CET, MDM, grading criteria) |
| [`3_Hop_ETL_Test/`](3_Hop_ETL_Test/README.md) | Hop ETL test project, Docker sources, pipelines, workflows, MDM demo |
| [`4_Official_Hop_Project/`](4_Official_Hop_Project/) | Official Hop project (production-style ETL — see Part 3) |
| [`.cursor/skills/`](.cursor/skills/README.md) | Cursor Agent skills for designing and debugging Hop ETL |
| [`.cursor/rules/`](.cursor/rules/hop-etl.mdc) | Lightweight guardrails when editing `.hpl` / `.hwf` files |

High-level data flow:

```
Sources (PG + Mongo) ──pull──► staging files ──► dw_staging
Backend (Go)         ──push──► Hop Web Service ──► staging.stg_users
dw_staging ──► dw_nds (3NF) ──► dw_dds (star schema) ──► Power BI
```

---

## 2. Part 1 — Cursor AI skills (project & personal)

This repository includes **Cursor Agent Skills** so you and your team can design and debug Hop ETL consistently — in Cursor chat or with any AI tool that can read the skill files.

### 2.1. What are project skills?

**Project skills** live under `.cursor/skills/` in this git repo. When anyone opens the repository in **Cursor**, the agent can load them when you type:

| Invoke in chat | Purpose |
|----------------|---------|
| `/design-hop-etl` | Design pipelines, workflows, configs, MDM, NDS/DDS patterns |
| `/debug-hop-etl` | Diagnose failures, read logs, verify data, fix common errors |
| `/learn-and-upgrade-hop-etl-skills` | Persist new lessons into design/debug skills; sync to `~/.cursor/skills/` |

**Personal skills** are an optional copy in `~/.cursor/skills/` on your machine. Use them if you want the same slash commands outside this repo, or after you re-sync following a `git pull`.

**Guideline for the team:** edit skills **only in the repository**, commit, push, then each member runs the sync script (section 2.4). Do not maintain a divergent copy only on your laptop.

### 2.2. Skill structure in this repo

```
.cursor/
├── rules/
│   └── hop-etl.mdc                 # Auto hints when editing .hpl / .hwf
└── skills/
    ├── README.md                   # Maintainer notes (short)
    ├── sync-to-personal.sh         # Copy skills → ~/.cursor/skills/
    ├── design-hop-etl/
    │   ├── SKILL.md                # Main design guide (/design-hop-etl)
    │   ├── reference.md            # XML/SQL templates (TextFileInput2, batch_id, LSET/CET)
    │   └── scripts/
    │       └── validate-hpl.sh     # xmllint + project pitfall checks
    ├── debug-hop-etl/
    │   └── SKILL.md                # Troubleshooting guide (/debug-hop-etl)
    └── learn-and-upgrade-hop-etl-skills/
        ├── SKILL.md                # Upgrade design/debug from session lessons
        └── learning-log.md         # Optional audit trail
```

**Automatic learning:** `/design-hop-etl` and `/debug-hop-etl` include a **final step** that runs the learn skill when the session produced meaningful new knowledge (otherwise NOOP — no file changes, no sync).

**`learn-and-upgrade-hop-etl-skills`** covers:

- Reviewing the session for durable Hop ETL lessons (pitfalls, symptom→fix, XML patterns)
- Updating `design-hop-etl` and/or `debug-hop-etl` in `.cursor/skills/` (minimal diffs)
- **NOOP** when nothing new is worth persisting (no edit, no sync)
- Running `sync-to-personal.sh` after real updates → `~/.cursor/skills/`

**`design-hop-etl`** covers:

- Project layout (`pipelines/01`–`09`, `workflows/`, `metadata/`)
- `development_configs.json` variables and connection metadata
- Docker topology (ports 5432–5436, Mongo 27017, Hop Server 8080)
- Incremental export (LSET/CET), staging load, workflow orchestration
- MDM push (`09_Push_MDM_Users_To_ETL_Hop`)
- NDS/DDS patterns (`07`, `08`) and assignment alignment with `2_Guidelines`
- XML pitfalls (empty TextFileInput2 files, `batch_id` + `use_formatting=Y`)

**`debug-hop-etl`** covers:

- Symptom → cause → fix table (`IllegalArgumentException`, `SAXParseException`, MDM 401, wrong `batch_id`)
- Reading `3_Hop_ETL_Test/workflows/workflow_logs/`
- Docker and SQL verification commands
- When to re-run via workflow vs single pipeline

See [section 2.7](#27-pipeline-xml-validation-validate-hplsh) for how skills and humans run `validate-hpl.sh`.

### 2.3. How to use skills in Cursor (project level)

1. Clone this repository and open the **repository root** in Cursor.
2. In the chat input, type `/design-hop-etl`, `/debug-hop-etl`, or `/learn-and-upgrade-hop-etl-skills` before your question.

**Examples:**

- `/design-hop-etl Add a staging load pipeline for a new exported file following folder 06 patterns.`
- `/debug-hop-etl TextFileInput2 fails with IllegalArgumentException on 01_load_exported_ratings_to_staging.hpl`
- `/learn-and-upgrade-hop-etl-skills We fixed batch_id Constant — persist use_formatting=Y pitfall.`

No install step is required for project-level skills — they ship with the repo.

### 2.4. How to sync project skills to personal skills

Use this when you want `/design-hop-etl`, `/debug-hop-etl`, and `/learn-and-upgrade-hop-etl-skills` in your **personal** Cursor skills folder (e.g. across workspaces).

#### macOS / Linux

From the **repository root**:

```bash
chmod +x .cursor/skills/sync-to-personal.sh
.cursor/skills/sync-to-personal.sh
```

This copies:

- `.cursor/skills/design-hop-etl/` → `~/.cursor/skills/design-hop-etl/`
- `.cursor/skills/debug-hop-etl/` → `~/.cursor/skills/debug-hop-etl/`
- `.cursor/skills/learn-and-upgrade-hop-etl-skills/` → `~/.cursor/skills/learn-and-upgrade-hop-etl-skills/`

Re-run after every `git pull` that changes `.cursor/skills/`.

#### Windows (Git Bash or WSL)

From the **repository root** (Git Bash):

```bash
chmod +x .cursor/skills/sync-to-personal.sh
.cursor/skills/sync-to-personal.sh
```

In **PowerShell** (manual copy):

```powershell
$repo = (Get-Location).Path
$dest = "$env:USERPROFILE\.cursor\skills"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force "$repo\.cursor\skills\design-hop-etl" "$dest\design-hop-etl"
Copy-Item -Recurse -Force "$repo\.cursor\skills\debug-hop-etl" "$dest\debug-hop-etl"
Copy-Item -Recurse -Force "$repo\.cursor\skills\learn-and-upgrade-hop-etl-skills" "$dest\learn-and-upgrade-hop-etl-skills"
Write-Host "Synced skills to $dest"
```

**Important:** `~/.cursor/skills-cursor/` is reserved by Cursor — never write skills there.

### 2.5. How to maintain and upgrade skills (team)

1. Edit `SKILL.md` or `reference.md` under `.cursor/skills/`.
2. Keep each `SKILL.md` focused (under ~500 lines); put long XML in `reference.md`.
3. Add new pitfalls when you fix a recurring Hop bug.
4. Run `validate-hpl.sh` on example pipelines you reference.
5. Commit, push, notify team to `git pull` and optionally re-run `sync-to-personal.sh`.

See also: [`.cursor/skills/README.md`](.cursor/skills/README.md).

### 2.6. Using skills with AI assistants — quick prompts

If your AI tool does not support slash commands, attach or point it at:

- `.cursor/skills/design-hop-etl/SKILL.md`
- `.cursor/skills/debug-hop-etl/SKILL.md`

**Template prompt:**

```text
Follow .cursor/skills/design-hop-etl/SKILL.md and 2_Guidelines/README.md.
Task: [describe pipeline/workflow change]
Constraints: use development_configs.json variables; validate .hpl with validate-hpl.sh.
```

### 2.7. Pipeline XML validation (`validate-hpl.sh`)

The script lives at `.cursor/skills/design-hop-etl/scripts/validate-hpl.sh`. It checks:

1. **Well-formed XML** — via `xmllint` (required on your PATH)
2. **Common project pitfalls** — empty `<files/>` / `<fields/>`, missing `STAGING_BATCH_ID` on Constant transforms

#### Can `/design-hop-etl` and `/debug-hop-etl` run it?

**Yes — indirectly.** Skills do not run automatically when you type a slash command. They **instruct the Cursor agent** to execute `validate-hpl.sh` as part of its work:

| Skill | When the agent should run `validate-hpl.sh` |
|-------|---------------------------------------------|
| `/design-hop-etl` | After creating or editing any `.hpl` (required before finishing the task) |
| `/debug-hop-etl` | When diagnosing `SAXParseException`, cannot open pipeline, or suspect Hop GUI stripped XML |

You can also ask explicitly, for example:

- `/design-hop-etl Add stg_foo load pipeline and validate the .hpl with validate-hpl.sh`
- `/debug-hop-etl SAX error on 03_load_exported_movies — run validate-hpl.sh and fix`

The `.cursor/rules/hop-etl.mdc` rule reinforces the same check when you edit `.hpl` files in this repo.

#### Run it yourself (human or CI)

**macOS / Linux** — `xmllint` is usually pre-installed (or via `brew install libxml2`):

```bash
chmod +x .cursor/skills/design-hop-etl/scripts/validate-hpl.sh

# Single file
.cursor/skills/design-hop-etl/scripts/validate-hpl.sh \
  3_Hop_ETL_Test/pipelines/06_Load_Exported_Files_To_Staging/01_load_exported_ratings_to_staging.hpl

# All pipelines
find 3_Hop_ETL_Test/pipelines -name '*.hpl' \
  -exec .cursor/skills/design-hop-etl/scripts/validate-hpl.sh {} \;
```

**Windows** — install `xmllint` via [Git for Windows](https://git-scm.com/download/win) (often bundled) or WSL, then run the same commands in Git Bash or WSL from the repository root.

### 2.8. Learn and upgrade skills (`/learn-and-upgrade-hop-etl-skills`)

Hop ETL knowledge from your chats (new pitfalls, fixes, XML patterns) can be **written back** into the project skills so the whole team benefits.

#### What it does

1. Reviews the current session for **durable** lessons (not one-off noise).
2. Updates `.cursor/skills/design-hop-etl` and/or `.cursor/skills/debug-hop-etl` (small, targeted edits).
3. Runs `.cursor/skills/sync-to-personal.sh` → copies all three skills to `~/.cursor/skills/`.
4. **NOOP** if nothing meaningful — no file changes, no sync.

Full workflow: [`.cursor/skills/learn-and-upgrade-hop-etl-skills/SKILL.md`](.cursor/skills/learn-and-upgrade-hop-etl-skills/SKILL.md)

#### Automatic trigger from design / debug

At the **end** of every `/design-hop-etl` or `/debug-hop-etl` session, the agent must run the learn skill workflow and report either:

- **Skill upgrade summary** (what changed + sync done), or  
- **No skill updates** — nothing new to persist.

You do not need to type `/learn-and-upgrade-hop-etl-skills` separately unless you want a manual capture.

#### Manual use

```text
/learn-and-upgrade-hop-etl-skills
Session summary: [what you learned or fixed this session]
```

#### Team workflow

1. Agent or developer updates `.cursor/skills/` in the repo.
2. `sync-to-personal.sh` updates the local machine.
3. **Commit and push** `.cursor/skills/` so teammates get updates via `git pull` + optional re-sync.

Optional audit trail: [`.cursor/skills/learn-and-upgrade-hop-etl-skills/learning-log.md`](.cursor/skills/learn-and-upgrade-hop-etl-skills/learning-log.md)

---

## 3. Part 2 — Hop ETL Test (`3_Hop_ETL_Test`)

Local development uses **Docker** for all databases. You do **not** need a full PostgreSQL server installed on the host unless you want a desktop SQL client. **Apache Hop** and **Docker Desktop** are required on every developer machine.

Detailed connection tables, MDM push, and verify SQL: [`3_Hop_ETL_Test/README.md`](3_Hop_ETL_Test/README.md).

### 3.1. Prerequisites and tool installation

| Tool | Required? | Purpose |
|------|-----------|---------|
| **Java 21** (recommended) | Yes | Apache Hop runtime — current Hop releases target JDK 21 |
| **Apache Hop** | Yes | ETL GUI, workflows, Hop Server |
| **Docker Desktop** | Yes | PostgreSQL + MongoDB fake sources and DW layers |
| **Git** | Yes | Clone this repository |
| **Cursor** (recommended) | Optional | IDE + project skills |
| **Go 1.21+** | Optional | Run MDM push demo (`3_Hop_ETL_Test/backend/`) |
| **PostgreSQL client** (`psql`) | Optional | Debugging; can use `docker exec` instead |

#### 3.1.1. Java 21 (highly recommended)

Apache Hop’s current releases expect **JDK 21**. Older JDKs (e.g. 17) may fail to start the GUI or Server. Use Java 21 unless your course specifies otherwise.

**macOS (Homebrew):**

```bash
brew install openjdk@21
# Link so `java` resolves to 21 (follow brew caveats if shown):
sudo ln -sfn "$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home" /Library/Java/JavaVirtualMachines/openjdk-21.jdk
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
java -version
```

**Windows:**

1. Download [Eclipse Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21) (LTS).
2. Run the installer (enable “Set JAVA_HOME” if offered).
3. Verify in PowerShell or CMD:

```powershell
java -version
# Should report version 21.x
```

If multiple Java versions are installed, set `JAVA_HOME` to the JDK 21 folder (e.g. `C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot`).

#### 3.1.2. Apache Hop

1. Download the latest stable release: [https://hop.apache.org/download/](https://hop.apache.org/download/)
2. Extract to a permanent folder, for example:
   - macOS: `/Applications/apache-hop` or `~/apache-hop`
   - Windows: `C:\apache-hop`

**Verify (macOS / Linux):**

```bash
cd /path/to/apache-hop
./hop-gui.sh --version
```

**Verify (Windows):**

```cmd
cd C:\apache-hop
hop-gui.bat
```

Official docs: [Hop GUI](https://hop.apache.org/manual/latest/hop-gui/) | [Hop Server](https://hop.apache.org/manual/latest/hop-server/)

#### 3.1.3. Docker Desktop

**macOS:**

```bash
brew install --cask docker
open -a Docker
docker info
```

Or install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/).

**Windows:**

1. Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).
2. Enable WSL 2 backend if prompted.
3. Start Docker Desktop from the Start menu.
4. Verify:

```powershell
docker info
```

If you see `failed to connect to the docker API`, wait 30–60 seconds and retry, or restart Docker Desktop.

#### 3.1.4. Optional — PostgreSQL client and Go

**psql (optional):** use `docker exec ... psql` (section 3.3) or install:

- macOS: `brew install libpq`  
- Windows: [PostgreSQL binaries](https://www.postgresql.org/download/windows/) (client tools only)

**Go (MDM demo only):**

- macOS: `brew install go`  
- Windows: [https://go.dev/dl/](https://go.dev/dl/)

---

### 3.2. First-time project setup

Run once per machine after cloning:

#### 3.2.1. Set `PROJECT_HOME` in Hop config

Hop resolves file paths from `3_Hop_ETL_Test/development_configs.json`. Update `PROJECT_HOME` to your local absolute path.

**macOS / Linux:**

```bash
cd 3_Hop_ETL_Test
python3 -c "
import json, pathlib
p = pathlib.Path('development_configs.json')
d = json.load(p.open())
home = str(pathlib.Path('.').resolve())
next(v for v in d['variables'] if v['name'] == 'PROJECT_HOME')['value'] = home
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
print('Updated PROJECT_HOME →', home)
"
```

**Windows (PowerShell):**

```powershell
cd 3_Hop_ETL_Test
$home = (Get-Location).Path
$json = Get-Content development_configs.json -Raw | ConvertFrom-Json
($json.variables | Where-Object { $_.name -eq 'PROJECT_HOME' }).value = $home
$json | ConvertTo-Json -Depth 10 | Set-Content development_configs.json
Write-Host "Updated PROJECT_HOME → $home"
```

#### 3.2.2. Register the Hop project (one-time in Hop GUI)

1. Start Hop GUI (section 3.4).
2. **File → Open pipeline** or **Open workflow** under `3_Hop_ETL_Test/`.
3. Ensure the Hop **environment** and **project** match your team setup:
   - Environment: `Hop_ETL_Test_Configs`
   - Project: `HCMUS_Master_IS_BI_Hop_ETL_Test`
4. If prompted, point metadata to `3_Hop_ETL_Test/metadata/` and config to `development_configs.json`.

Ask your team lead if environment names differ on your machine — they must match what you pass to `hop-server.sh` (section 3.5).

---

### 3.3. Docker Compose — start, stop, reset

All services are defined in `3_Hop_ETL_Test/docker/docker-compose.yml`. Compose project name: **hcmus-master-is-bi-db**.

#### 3.3.1. Start databases (detached)

**macOS / Linux / Windows (same commands):**

```bash
cd 3_Hop_ETL_Test/docker
docker compose up -d
docker compose ps
```

Older Docker installs may use `docker-compose` (with hyphen) instead of `docker compose`.

#### 3.3.2. View logs

```bash
cd 3_Hop_ETL_Test/docker
docker compose logs -f
```

#### 3.3.3. Stop containers (keep data)

```bash
cd 3_Hop_ETL_Test/docker
docker compose down
```

#### 3.3.4. Stop and delete volumes (full reset + re-seed)

Use when SQL init scripts or schemas changed:

```bash
cd 3_Hop_ETL_Test/docker
docker compose down -v
docker compose up -d
```

#### 3.3.5. Quick health check

```bash
docker exec hcmus-master-is-bi-db-src-ratings-revenues \
  psql -U hop_reader -d ratings_revenues -c "SELECT COUNT(*) FROM ratings;"

docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_staging -d dw_staging -c "\dt staging.*"
```

| Host port | Role |
|-----------|------|
| 5432 | Source — ratings & revenues |
| 5433 | Source — users |
| 5434 | DW — staging, control, metadata (separate DBs) |
| 5435 | DW — NDS |
| 5436 | DW — DDS (Power BI) |
| 27017 | MongoDB — movies, genres, persons |

---

### 3.4. Run Apache Hop GUI

Use Hop GUI to edit pipelines (`.hpl`), workflows (`.hwf`), and run ETL locally.

#### 3.4.1. macOS / Linux

```bash
cd /path/to/apache-hop
./hop-gui.sh
```

Optional — set config folder if your team uses a custom Hop config path:

```bash
export HOP_CONFIG_FOLDER=/path/to/apache-hop/config
./hop-gui.sh
```

#### 3.4.2. Windows

```cmd
cd C:\apache-hop
hop-gui.bat
```

#### 3.4.3. Open this project in the GUI

1. Navigate to `3_Hop_ETL_Test/workflows/`.
2. Open `00_master_staging_etl_workflow.hwf` for the full export + load chain.
3. Select environment **`Hop_ETL_Test_Configs`** and project **`HCMUS_Master_IS_BI_Hop_ETL_Test`** in the Hop toolbar.
4. Press **Run** on the workflow.

**Before running ETL:** Docker must be up (section 3.3) and `PROJECT_HOME` must be set (section 3.2.1).

**AI-assisted editing:** use `/design-hop-etl` in Cursor when creating pipelines; run `validate-hpl.sh` after GUI saves (Hop can strip XML fields).

---

### 3.5. Run Apache Hop Server (MDM Web Service)

Hop Server exposes the MDM **Users** Web Service (`mdm-users`) for real-time push from the Go backend. Required only for MDM testing — not for batch export/load workflows.

#### 3.5.1. Prerequisites

1. Docker running (`dw_staging` on port 5434).
2. `PROJECT_HOME` set in `development_configs.json`.
3. Apache Hop extracted and environment/project registered (section 3.2.2).

#### 3.5.2. Start server

**macOS / Linux:**

```bash
cd /path/to/apache-hop

# Optional if Hop cannot find config:
# export HOP_CONFIG_FOLDER=/path/to/apache-hop/config

./hop-server.sh \
  -e "Hop_ETL_Test_Configs" \
  -j HCMUS_Master_IS_BI_Hop_ETL_Test \
  127.0.0.1 8080
```

With explicit credentials (defaults are `cluster` / `cluster`):

```bash
./hop-server.sh \
  -e "Hop_ETL_Test_Configs" \
  -j HCMUS_Master_IS_BI_Hop_ETL_Test \
  -u cluster -p cluster \
  127.0.0.1 8080
```

**Windows:**

```cmd
cd C:\apache-hop
hop-server.bat -e "Hop_ETL_Test_Configs" -j HCMUS_Master_IS_BI_Hop_ETL_Test 127.0.0.1 8080
```

**Notes:**

- Host and port (`127.0.0.1 8080`) are **positional arguments** at the end.
- `-p` means **password**, not port.
- Web Service URL: `http://127.0.0.1:8080/hop/webService/?service=mdm-users`

#### 3.5.3. Test MDM push

**Go demo:**

```bash
cd 3_Hop_ETL_Test/backend
go run .
```

**curl:**

```bash
curl -u cluster:cluster -X POST \
  "http://127.0.0.1:8080/hop/webService/?service=mdm-users" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: local-dev-mdm-key" \
  -d '{"operation":"INSERT","sent_at":"2024-06-10T10:00:00.000Z","data":{"user_id":99,"username":"henry","email":"henry@movielens.local","age":30,"gender":"M","occupation":"analyst","created_at":"2024-06-10T10:00:00.000Z","last_update_timestamp":"2024-06-10T10:00:00.000Z"}}'
```

**Verify staging:**

```bash
docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_staging -d dw_staging \
  -c "SELECT user_id, username, operation, batch_id FROM staging.stg_users ORDER BY loaded_at DESC LIMIT 5;"
```

Full MDM documentation: [`3_Hop_ETL_Test/README.md` — How to push MDM data](3_Hop_ETL_Test/README.md#how-to-push-mdm-data-to-etl-hop).

---

### 3.6. Run ETL workflows (GUI)

Recommended run order:

| Step | Workflow file | What it does |
|------|---------------|--------------|
| 1 | `workflows/01_sub_workflow_export_all_data_sources_to_files.hwf` | Incremental pull → `staging/exported_*` |
| 2 | `workflows/02_sub_workflow_load_exported_files_to_staging.hwf` | Files → `dw_staging.staging.*` |
| Or both | `workflows/00_master_staging_etl_workflow.hwf` | Export then load |

Logs are written to `3_Hop_ETL_Test/workflows/workflow_logs/`.

If something fails, use `/debug-hop-etl` in Cursor with the log file name and error message.

---

### 3.7. Where to read more

| Topic | Document |
|-------|----------|
| Docker services, connections, verify SQL | [`3_Hop_ETL_Test/README.md`](3_Hop_ETL_Test/README.md) |
| Assignment rules (3NF, SCD, LSET/CET, MDM) | [`2_Guidelines/README.md`](2_Guidelines/README.md) |
| Hop ETL design patterns (AI) | [`.cursor/skills/design-hop-etl/SKILL.md`](.cursor/skills/design-hop-etl/SKILL.md) |
| Hop ETL debugging (AI) | [`.cursor/skills/debug-hop-etl/SKILL.md`](.cursor/skills/debug-hop-etl/SKILL.md) |
| Apache Hop official manual | [https://hop.apache.org/manual/latest/](https://hop.apache.org/manual/latest/) |

---

## 4. Part 3 — Official Hop Project (`4_Official_Hop_Project`)

> **Status: placeholder** — this section will be expanded when the official project is ready.

The [`4_Official_Hop_Project/`](4_Official_Hop_Project/) folder is reserved for the **production-style** Apache Hop project (separate from the local test sandbox in `3_Hop_ETL_Test/`).

| Item | Current state |
|------|----------------|
| Folder | `4_Official_Hop_Project/` |
| `project-config.json` | Present (skeleton) |
| `development_configs.json` | Present (skeleton) |
| Pipelines / workflows | *To be added* |
| README | *To be added* |

**Planned use (draft):**

1. Final ETL pipelines and workflows deployed toward course VMs / production-like targets.
2. Shared Hop environment and project names aligned with your team’s official Hop config.
3. Reuse the same Cursor skills (`/design-hop-etl`, `/debug-hop-etl`, `/learn-and-upgrade-hop-etl-skills`) and `validate-hpl.sh` — point paths at `4_Official_Hop_Project/pipelines/` when that content exists.

**Until this is documented:** continue development and testing in [`3_Hop_ETL_Test/`](3_Hop_ETL_Test/README.md). Check back here after the team publishes the official project README.

---

## 5. Related documentation

- **Architecture diagram:** [`2_Guidelines/Expected_Data_Warehouse_Architecture.png`](2_Guidelines/Expected_Data_Warehouse_Architecture.png)
- **Skills maintainer guide:** [`.cursor/skills/README.md`](.cursor/skills/README.md)
- **Hop XML guardrails:** [`.cursor/rules/hop-etl.mdc`](.cursor/rules/hop-etl.mdc)

---

*HCMUS Master of Information Systems — Advanced Business Intelligence*
