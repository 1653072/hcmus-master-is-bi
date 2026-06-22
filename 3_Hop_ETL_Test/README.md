# 3_Hop_ETL_Test — Local Fake Data Sources (Docker)

Compose project: **hcmus-master-is-bi-db**

Matches `./development_configs.json` ports and credentials.

## Set PROJECT_HOME (run once per machine)

Apache Hop uses `PROJECT_HOME` from `development_configs.json` for paths such as `staging/csv` and `staging/jsonl`. Run this from the **3_Hop_ETL_Test** folder (this directory):

### macOS / Linux

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

### Windows (PowerShell)

```powershell
cd 3_Hop_ETL_Test
$home = (Get-Location).Path
$json = Get-Content development_configs.json -Raw | ConvertFrom-Json
($json.variables | Where-Object { $_.name -eq 'PROJECT_HOME' }).value = $home
$json | ConvertTo-Json -Depth 10 | Set-Content development_configs.json
Write-Host "Updated PROJECT_HOME → $home"
```

## Images


| Project name         | Docker Hub pull      |
| -------------------- | -------------------- |
| `postgres@16-alpine` | `postgres:16-alpine` |
| `mongo@7`            | `mongo:7`            |


Docker uses `:` for image tags. This README uses `@` as a readable version label.

## Start Docker Desktop (required before compose)

`docker-compose` needs the Docker daemon running. If you see `failed to connect to the docker API ... docker.sock`, start Docker Desktop first.

### macOS

```bash
# GUI: open Docker Desktop from Applications
open -a Docker

# Wait until ready, then verify
docker info
```

Or launch **Docker Desktop** from Applications and wait until the menu bar whale icon shows **Running**.

### Windows

```powershell
# GUI: Start Menu → Docker Desktop

# Or from PowerShell / CMD
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait until ready, then verify
docker info
```

If `docker info` fails, wait 30–60 seconds and retry. Use **Docker Desktop → Troubleshoot → Restart** if it still fails.

## Services


| Service            | Container                                    | Image              | Host port | Databases                                 |
| ------------------ | -------------------------------------------- | ------------------ | --------- | ----------------------------------------- |
| Ratings & Revenues | `hcmus-master-is-bi-db-src-ratings-revenues` | postgres@16-alpine | 5432      | `ratings_revenues`                        |
| Users              | `hcmus-master-is-bi-db-src-users`            | postgres@16-alpine | 5433      | `users`                                   |
| MongoDB            | `hcmus-master-is-bi-db-src-mongo`            | mongo@7            | 27017     | `movielens_auth`, `movielens_data`        |
| DW — Staging layer | `hcmus-master-is-bi-db-dw-stg-postgres`      | postgres@16-alpine | 5434      | `dw_staging`, `dw_control`, `dw_metadata` |
| DW — NDS layer     | `hcmus-master-is-bi-db-dw-nds-postgres`      | postgres@16-alpine | 5435      | `dw_nds`                                  |
| DW — DDS layer     | `hcmus-master-is-bi-db-dw-dds-postgres`      | postgres@16-alpine | 5436      | `dw_dds` (Power BI reads here)            |


## Commands

From repo root:

```bash
cd 3_Hop_ETL_Test/docker
docker-compose up -d
docker-compose ps
docker-compose logs -f
docker-compose down
docker-compose down -v   # reset volumes + re-seed on next up
```

Or from this folder (`3_Hop_ETL_Test`):

```bash
cd docker
docker-compose up -d
docker-compose ps
docker-compose logs -f
docker-compose down
docker-compose down -v
```

## Quick verify

`dw-stg-postgres` runs **3 separate PostgreSQL databases** on port 5434 — not 3 schemas in one DB:


| Database      | Schema     | User           |
| ------------- | ---------- | -------------- |
| `dw_staging`  | `staging`  | `hop_staging`  |
| `dw_control`  | `control`  | `hop_control`  |
| `dw_metadata` | `metadata` | `hop_metadata` |


```bash
# Ratings & Revenues database (PostgreSQL - Data in CSV format)
docker exec hcmus-master-is-bi-db-src-ratings-revenues psql -U hop_reader -d ratings_revenues -c "SELECT COUNT(*) FROM ratings;"

# Movie database (MongoDB - Data in JSONL format)
docker exec hcmus-master-is-bi-db-src-mongo mongosh -u hop_reader -p hop_reader --authenticationDatabase movielens_auth movielens_data --eval "db.movies.countDocuments()"

# staging tables → database dw_staging (PostgreSQL)
docker exec hcmus-master-is-bi-db-dw-stg-postgres psql -U hop_staging -d dw_staging -c "\dt staging.*"

# control tables → database dw_control (PostgreSQL)
docker exec hcmus-master-is-bi-db-dw-stg-postgres psql -U hop_control -d dw_control -c "\dt control.*"

# metadata tables → database dw_metadata (PostgreSQL)
docker exec hcmus-master-is-bi-db-dw-stg-postgres psql -U hop_metadata -d dw_metadata -c "\dt metadata.*"

# NDS database (PostgreSQL)
docker exec hcmus-master-is-bi-db-dw-nds-postgres psql -U hop_nds -d dw_nds -c "\dn"

# DDS database (PostgreSQL)
docker exec hcmus-master-is-bi-db-dw-dds-postgres psql -U hop_dds -d dw_dds -c "\dn"
```

## Connection hints


| Role                   | Host      | Port | Database      | User               |
| ---------------------- | --------- | ---- | ------------- | ------------------ |
| Hop staging load       | localhost | 5434 | `dw_staging`  | `hop_staging`      |
| Hop control (LSET/CET) | localhost | 5434 | `dw_control`  | `hop_control`      |
| Hop metadata           | localhost | 5434 | `dw_metadata` | `hop_metadata`     |
| Hop NDS load           | localhost | 5435 | `dw_nds`      | `hop_nds`          |
| Hop DDS load           | localhost | 5436 | `dw_dds`      | `hop_dds`          |
| Power BI               | localhost | 5436 | `dw_dds`      | `analytics_reader` |


## MongoDB connection

```
mongodb://hop_reader:hop_reader@localhost:27017/movielens_data?authSource=movielens_auth
```


| Database         | Purpose                                                                         |
| ---------------- | ------------------------------------------------------------------------------- |
| `movielens_auth` | Stores `hop_reader` credentials (`authSource` / `--authenticationDatabase`)     |
| `movielens_data` | Stores collections `movies`, `genres`, `persons` (URI path / mongosh target DB) |


### mongosh example

```bash
mongosh -u hop_reader -p hop_reader \
  --authenticationDatabase movielens_auth \   # WHERE credentials are checked
  movielens_data \                            # WHICH database to query
  --eval "db.movies.countDocuments()"
```

Auth DB and data DB use separate names to avoid confusion.

---

## How to push MDM data to ETL Hop

This flow lets the **Backend Users service** send master-data changes to Apache Hop in real time. The Go demo in `backend/` POSTs a JSON user record to Hop’s **Sync Web Service**. Hop validates the request, reconciles the operation against the NDS, and upserts **one current row per user** into `staging.stg_users`.

### What happens end-to-end

1. **Backend** (`backend/push_mdm_user.go`) builds a JSON payload (`operation`, `sent_at`, `data`) and POSTs it to Hop with **HTTP Basic Auth** (Hop Server) and header **`X-API-Key`** (MDM API key). See [HTTP authentication](#http-authentication-two-layers) below.
2. **Hop Web Service** receives the HTTP call at `/hop/webService/?service=mdm-users` (query param is `service`, not `service_id`).
3. **Hop** runs two pipelines in sequence (see below): first security/routing, then business logic.
4. **Staging** stores the latest state per `user_id` in `staging.stg_users`.
5. **Hop** returns JSON with `status`, `user_id`, and ETL-generated `batch_id`.

There is **no `event_id`** anywhere — the Backend does not send UUIDs. Retries from the Go client are safe because staging upserts by `user_id`.

### Two Hop pipelines (why two?)

Hop splits the work so the Web Service entry point stays thin and entity-specific logic can grow later (e.g. `mdm-movies`).

```mermaid
flowchart TB
    subgraph BE [Backend Go]
        GoPush[push_mdm_user.go]
    end
    subgraph HopServer [Hop Server :8080]
        WS["/hop/webService/?service=mdm-users"]
        Entry["00_mdm_service_redirection.hpl\n(Web Service entry — routing & auth)"]
        Store["01_store_pushed_mdm_user_from_backend_to_staging.hpl\n(Validate, reconcile, write staging)"]
    end
    subgraph DW [Data Warehouse]
        STG[(staging.stg_users)]
        NDS[(nds.users)]
        CTL[(control.etl_job_log)]
    end
    GoPush -->|"POST JSON + Basic Auth + X-API-Key"| WS
    WS --> Entry
    Entry -->|Pipeline Executor| Store
    Store --> STG
    Store --> NDS
    Store --> CTL
    Store --> Entry
    Entry --> GoPush
```




| Step                      | Pipeline file                                                                                 | Role in plain language                                                                                                                                                                                                                                                                   |
| ------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 — Web Service entry     | `pipelines/09_Push_MDM_Users_To_ETL_Hop/00_mdm_service_redirection.hpl`                       | **Row Generator** (1 row) → **Get variables** → **JSON Input** (headers) → **Coalesce** → **Filter rows** (API key) → Pipeline Executor or **Constant** (401). No JavaScript. |
| 2 — Store user in staging | `pipelines/09_Push_MDM_Users_To_ETL_Hop/01_store_pushed_mdm_user_from_backend_to_staging.hpl` | Second pipeline (not exposed directly on the URL). Parses JSON, validates fields, looks up `nds.users` to reconcile `operation`, upserts `staging.stg_users`, writes `control.etl_job_log`, returns result rows to step 1.                                                               |


Web Service metadata (`metadata/web-service/mdm-users.json`) points at **step 1** only. Step 2 is invoked internally via **Pipeline Executor**.

#### Why "Generate 1 row" (Row Generator)?

Hop pipelines are **row-based**: every transform needs at least one row flowing through it to execute. A Web Service HTTP call does not arrive as a row — Hop stores the POST body and headers in **variables** (`MDM_REQUEST_BODY`, `MDM_REQUEST_HEADERS`).

**Row Generator** creates exactly **one dummy row** to kick off the pipeline. **Get variables** then attaches the HTTP payload to that row. Limit must be **1** so the Web Service returns a single JSON response (not one per generated row).

#### `?service=` query param vs pipeline variables

The URL must include `?service=mdm-users` so Hop selects `metadata/web-service/mdm-users.json`. Apache Hop **does not** copy that query param into a `${service}` pipeline variable (it is reserved for servlet routing).

Inside the pipeline, the service id comes from **`HOP_MDM_USERS_SERVICE_ID`** in `development_configs.json`. Tier-1 routing already guarantees the correct web service metadata was loaded.

### Multi-MDM routing (2 tiers)

Future MDM entities (e.g. movies) can reuse the same pattern:

1. **Hop servlet:** `?service=mdm-users` → `metadata/web-service/mdm-users.json` → `00_mdm_service_redirection.hpl`
2. **Entry pipeline:** switch on `HOP_MDM_USERS_SERVICE_ID` (or a custom query param such as `?entity=mdm-users` — any param except `service` is passed as a pipeline variable) → Pipeline Executor → the matching storage pipeline

### Config keys (`development_configs.json`)


| Key                                | Scope  | Example                                          | Purpose                                                                                      |
| ---------------------------------- | ------ | ------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `HOP_MDM_API_HOST`                 | Shared | `127.0.0.1`                                      | Bind address for Hop Server (documentation / future use)                                     |
| `HOP_MDM_API_PORT`                 | Shared | `8080`                                           | Hop Server port                                                                              |
| `HOP_MDM_API_URL`                  | Shared | `http://127.0.0.1:8080/hop/webService/?service=` | Base URL; append service id for the full endpoint                                            |
| `HOP_MDM_USERS_API_KEY`            | Users  | `local-dev-mdm-key`                              | Expected value of `X-API-Key` header (must match Go constant)                                |
| `HOP_MDM_USERS_SERVICE_ID`         | Users  | `mdm-users`                                      | Query param `?service=`, `batch_id` prefix, and `metadata/web-service/mdm-users.json` `name` |
| `HOP_MDM_USERS_STAGING_TABLE`      | Users  | `stg_users`                                      | Target staging table                                                                         |
| `HOP_MDM_USERS_ALLOWED_OPERATIONS` | Users  | `INSERT,UPDATE,DELETE`                           | Allowed values for `operation` in the request body                                           |


Full endpoint URL:

`HOP_MDM_API_URL` + `HOP_MDM_USERS_SERVICE_ID` → `http://127.0.0.1:8080/hop/webService/?service=mdm-users`

(`127.0.0.1` and `localhost` are equivalent for local dev — use either in the Go client or curl.)

### HTTP authentication (two layers)

Every MDM push must pass **two independent checks**. They use different headers and fail in different ways.

| Layer | When it runs | Mechanism | Default local credentials | Typical failure |
| ----- | ------------ | --------- | ------------------------- | --------------- |
| **1 — Hop Server (Jetty)** | Before any pipeline executes | HTTP **Basic Auth** | Username `cluster`, password `cluster` | HTML page: `401 Unauthorized` |
| **2 — MDM entry pipeline** | Inside `00_mdm_service_redirection.hpl` | Header **`X-API-Key`** | `local-dev-mdm-key` (matches `HOP_MDM_USERS_API_KEY`) | JSON body: `{"status":"ERROR","message":"Unauthorized"}` |

**Important:** `Authorization: Basic cluster:cluster` is **not** the correct header value. Basic Auth sends the word `Basic` followed by a **Base64-encoded** `username:password` string.

| Piece | Value |
| ----- | ----- |
| Username | `cluster` |
| Password | `cluster` |
| Credentials (before encoding) | `cluster:cluster` |
| Base64 of `cluster:cluster` | `Y2x1c3RlcjpjbHVzdGVy` |
| Correct header | `Authorization: Basic Y2x1c3RlcjpjbHVzdGVy` |

Do not paste `cluster:cluster` literally after `Basic` — clients must encode it (or use a helper that does).

**Go** (`backend/push_mdm_user.go`):

```go
req.SetBasicAuth("cluster", "cluster")   // Hop Server
req.Header.Set("X-API-Key", "local-dev-mdm-key")  // MDM pipeline
```

**curl** (minimal smoke test):

```bash
curl -u cluster:cluster -X POST \
  "http://127.0.0.1:8080/hop/webService/?service=mdm-users" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: local-dev-mdm-key" \
  -d '{"operation":"INSERT","sent_at":"2024-06-10T10:00:00.000Z","data":{"user_id":99,"username":"henry","email":"henry@movielens.local","age":30,"gender":"M","occupation":"analyst","created_at":"2024-06-10T10:00:00.000Z","last_update_timestamp":"2024-06-10T10:00:00.000Z"}}'
```

(`-u cluster:cluster` sets Basic Auth automatically.)

**Postman / Insomnia:** Auth type **Basic Auth** → username `cluster`, password `cluster`; add a separate header `X-API-Key` = `local-dev-mdm-key`.

**Troubleshooting 401:**

| Symptom | Likely cause |
| ------- | -------------- |
| HTML `401 Unauthorized` (Jetty error page) | Missing or wrong **Basic Auth** — not related to using `127.0.0.1` vs `localhost` |
| JSON `401` with `"Unauthorized"` | Wrong **`X-API-Key`** — Basic Auth passed, MDM key failed |

Hop Server auth defaults are documented in the [Apache Hop Server manual](https://hop.apache.org/manual/latest/hop-server/index.html). Change them in production; for local dev the defaults are `cluster` / `cluster`.

### JSON request (Backend → Hop)

```json
{
  "operation": "INSERT",
  "sent_at": "2024-06-10T10:00:00.000Z",
  "data": {
    "user_id": 99,
    "username": "henry",
    "email": "henry@movielens.local",
    "age": 30,
    "gender": "M",
    "occupation": "analyst",
    "created_at": "2024-06-10T10:00:00.000Z",
    "last_update_timestamp": "2024-06-10T10:00:00.000Z"
  }
}
```


| Field                        | Required | Notes                                                       |
| ---------------------------- | -------- | ----------------------------------------------------------- |
| `operation`                  | Yes      | `INSERT`, `UPDATE`, or `DELETE` (see reconcile table below) |
| `sent_at`                    | Yes      | ISO-8601 timestamp from Backend                             |
| `data.user_id`               | Yes      | Business key; staging upsert key                            |
| `data.username`              | Yes      | Non-empty                                                   |
| `data.email`                 | Yes      | Valid email format                                          |
| `data.age`                   | Yes      | Must be > 0                                                 |
| `data.gender`                | Yes      | `M` or `F`                                                  |
| `data.occupation`            | No       | Optional                                                    |
| `data.created_at`            | Yes      | ISO-8601                                                    |
| `data.last_update_timestamp` | Yes      | ISO-8601                                                    |


Response example (`batch_id` is generated by ETL, not sent by Backend):

```json
{"status":"ACCEPTED","user_id":99,"batch_id":"mdm-users-99-20240610103000"}
```

HTTP status codes: `200` accepted, `400` validation error, `401` bad API key, `404` delete for unknown user in NDS.

### Operation reconcile (Backend intent vs NDS state)

The Backend sends what it *intends* (`INSERT` / `UPDATE` / `DELETE`). The storage pipeline checks whether `user_id` already exists in `nds.users` and writes a **reconciled** `operation` to staging (used later when loading staging → NDS).


| Backend `operation` | User exists in `nds.users`? | `operation` stored in `staging.stg_users` |
| ------------------- | --------------------------- | ----------------------------------------- |
| INSERT              | No                          | INSERT                                    |
| INSERT              | Yes                         | UPDATE                                    |
| UPDATE              | Yes                         | UPDATE                                    |
| UPDATE              | No                          | INSERT                                    |
| DELETE              | Yes                         | DELETE                                    |
| DELETE              | No                          | HTTP 404 — reject                         |


### Staging model (`staging.stg_users`)


| Rule             | Detail                                                                                   |
| ---------------- | ---------------------------------------------------------------------------------------- |
| One row per user | `user_id NOT NULL UNIQUE` — current-state mirror, not an event log                       |
| Upsert key       | `user_id` — repeat POST with same `user_id` overwrites the same row                      |
| `batch_id`       | ETL-generated: `{service_id}-{user_id}-{loaded_at}` (e.g. `mdm-users-99-20240610103000`) |
| `operation`      | Reconciled value (table above), not the raw Backend operation                            |
| No `event_id`    | Not in JSON, not in the table                                                            |


### Step-by-step

**1. Start databases** (re-seed if schema changed):

```bash
cd 3_Hop_ETL_Test/docker
docker-compose down -v && docker-compose up -d
```

**2. Set `PROJECT_HOME`** (see **Set PROJECT_HOME (run once per machine)** at the top of this README).

**3. Start Hop Server** from your Apache Hop install directory. Use the **lifecycle environment name** from Hop GUI / `hop-config.json` (not the `HOP_ENV=dev` variable inside `development_configs.json`):

```bash
cd /path/to/apache_hop_etl_engine

export HOP_CONFIG_FOLDER=/path/to/apache_hop_etl_engine/config   # if needed

./hop-server.sh \
  -e "Hop_ETL_Test_Configs" \
  -j HCMUS_Master_IS_BI_Hop_ETL_Test \
  127.0.0.1 8080
```

Host and port (`127.0.0.1 8080` or `0.0.0.0 8080`) are **positional arguments** at the end — the `-p` flag is **password**, not port.

To start Hop Server with explicit credentials (optional; defaults are `cluster` / `cluster`):

```bash
./hop-server.sh \
  -e "Hop_ETL_Test_Configs" \
  -j HCMUS_Master_IS_BI_Hop_ETL_Test \
  -u cluster -p cluster \
  127.0.0.1 8080
```

**4. Run Go push demo** (must compile all `.go` files in the package):

```bash
cd 3_Hop_ETL_Test/backend
go run .
```

**5. Verify staging:**

```bash
docker exec hcmus-master-is-bi-db-dw-stg-postgres \
  psql -U hop_staging -d dw_staging \
  -c "SELECT user_id, username, operation, batch_id, loaded_at FROM staging.stg_users ORDER BY loaded_at DESC LIMIT 5;"
```

### Validation order (after authentication)

Once Basic Auth and `X-API-Key` succeed, business validation runs in two pipeline layers:

**Layer 1 — Web Service entry pipeline** (`00_mdm_service_redirection.hpl`) — native transforms (no JavaScript):

1. **Get variables** — `expected_api_key` = `${HOP_MDM_USERS_API_KEY}`, plus `MDM_REQUEST_HEADERS`
2. **JSON Input** — parse headers; read `$['X-Api-Key']` and `$['X-API-Key']`
3. **Coalesce** — `incoming_api_key` (first non-empty header value)
4. **Filter rows** — `incoming_api_key` = `expected_api_key` → storage pipeline; else → **Constant** (`401`, `Unauthorized` JSON)

`?service=mdm-users` is enforced by the Hop servlet (not inside the pipeline). Failure → `401` before staging logic runs.

**Layer 2 — User storage pipeline** (`01_store_pushed_mdm_user_from_backend_to_staging.hpl`):

- `data.email` — valid email format
- `data.age` > 0
- `data.username` — non-empty
- `data.user_id` > 0
- `data.gender` — `M` or `F`
- `data.occupation` — optional
- `data.created_at`, `data.last_update_timestamp` — required ISO-8601 timestamps
- `operation` — must be in `HOP_MDM_USERS_ALLOWED_OPERATIONS`
- DELETE when user not in NDS → `404`

### Late arriving dimension (staging → NDS, future workflow)

Ratings can arrive in staging before the user master row exists in NDS. When loading `stg_ratings` into NDS, verify `user_id` exists in **`nds.users`** or **`staging.stg_users`** before writing fact rows.

If master data is still missing:

- **Staging fallback:** keep the rating in staging until a Users MDM push arrives
- **Skeleton dimension:** insert a minimal `nds.users` row with only `user_id`, then fill attributes when master data arrives

Users MDM is pushed in real time, so the late-arriving window is usually shorter than for daily pull sources (ratings, MongoDB).