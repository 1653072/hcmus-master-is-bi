# Local Fake Data Sources (Docker)

Matches `../development_configs.json` ports and credentials.

## Services

| Service | Container | Host port | Databases |
|---------|-----------|-----------|-----------|
| Ratings & Revenues | `src-ratings-revenues` | 5432 | `ratings_revenues` |
| Users | `src-users` | 5433 | `users` |
| MongoDB | `src-mongo` | 27017 | `movielens_auth`, `movielens_data` |
| DW — Staging layer | `dw-stg-postgres` | 5434 | `dw_staging`, `dw_control`, `dw_metadata` |
| DW — NDS layer | `dw-nds-postgres` | 5435 | `dw_nds` |
| DW — DDS layer | `dw-dds-postgres` | 5436 | `dw_dds` (Power BI reads here) |

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

```bash
docker exec src-ratings-revenues psql -U hop_reader -d ratings_revenues -c "SELECT COUNT(*) FROM ratings;"
docker exec src-mongo mongosh -u hop_reader -p hop_reader --authenticationDatabase movielens_auth movielens_data --eval "db.movies.countDocuments()"
docker exec dw-stg-postgres psql -U hop_staging -d dw_staging -c "\dt staging.*"
docker exec dw-nds-postgres psql -U hop_nds -d dw_nds -c "\dn"
docker exec dw-dds-postgres psql -U hop_dds -d dw_dds -c "\dn"
```

## Connection hints

| Role | Host | Port | Database | User |
|------|------|------|----------|------|
| Hop staging load | localhost | 5434 | `dw_staging` | `hop_staging` |
| Hop control (LSET/CET) | localhost | 5434 | `dw_control` | `hop_control` |
| Hop metadata | localhost | 5434 | `dw_metadata` | `hop_metadata` |
| Hop NDS load | localhost | 5435 | `dw_nds` | `hop_nds` |
| Hop DDS load | localhost | 5436 | `dw_dds` | `hop_dds` |
| Power BI | localhost | 5436 | `dw_dds` | `analytics_reader` |

## MongoDB connection

```
mongodb://hop_reader:hop_reader@localhost:27017/movielens_data?authSource=movielens_auth
```

| Database | Purpose |
|----------|---------|
| `movielens_auth` | Stores `hop_reader` credentials (`authSource` / `--authenticationDatabase`) |
| `movielens_data` | Stores collections `movies`, `genres`, `persons` (URI path / mongosh target DB) |

### mongosh example

```bash
mongosh -u hop_reader -p hop_reader \
  --authenticationDatabase movielens_auth \   # WHERE credentials are checked
  movielens_data \                            # WHICH database to query
  --eval "db.movies.countDocuments()"
```

Auth DB and data DB are now separate names to avoid confusion.
