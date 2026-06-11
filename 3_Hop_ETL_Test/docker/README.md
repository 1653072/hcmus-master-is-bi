# Local Fake Data Sources (Docker)

Compose project: **hcmus-master-is-bi-db**

Matches `../development_configs.json` ports and credentials.

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

```bash
cd 3_Hop_ETL_Test/docker
docker-compose up -d
docker-compose ps
docker-compose logs -f
docker-compose down
docker-compose down -v   # reset volumes + re-seed on next up
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