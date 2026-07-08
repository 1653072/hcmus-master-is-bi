# Hop ETL skills — learning log

Optional audit trail. The learn skill may append one line per meaningful upgrade. Keep entries short.

| Date | Skill | Lesson |
|------|-------|--------|
| 2026-06-10 | (initial) | Skills created: design-hop-etl, debug-hop-etl, learn-and-upgrade-hop-etl-skills |
| 2026-06-22 | design + debug | MDM push verified: Hop Server `-e Hop_ETL_Test_Configs`, Basic Auth + X-API-Key, `go run .`, web-service metadata vars |
| 2026-06-22 | design | MDM entry uses ScriptValueMod for case-insensitive X-API-Key; metadata `bodyContentVariable`/`headerContentVariable` |
| 2026-06-22 | debug | Added MDM checklist: Docker 5434, lifecycle env name, connection refused / single-file Go run pitfalls |
| 2026-07-07 | design + debug | Source-file staging lessons: TextFileInput2 locale and UNIX/DOS formats, JSON numeric casts, and separate staging-count audit across `dw_staging`/`dw_control` |
