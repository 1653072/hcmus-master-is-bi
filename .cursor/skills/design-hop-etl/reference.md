# Design Hop ETL — XML & SQL Reference

Read this file when implementing or generating `.hpl` XML. Keep SKILL.md as the workflow guide; use this for copy-paste templates.

## TextFileInput2 — CSV

```xml
<transform>
  <type>TextFileInput2</type>
  <name>Read exported_ratings.csv</name>
  <separator>,</separator>
  <enclosure>"</enclosure>
  <header>Y</header>
  <nr_headerlines>1</nr_headerlines>
  <format>DOS</format>
  <encoding>UTF-8</encoding>
  <file>
    <name>${STAGING_RATINGS_DIR}/</name>
    <filemask>exported_ratings.csv</filemask>
    <file_required>Y</file_required>
    <include_subfolders>N</include_subfolders>
    <type>CSV</type>
    <compression>None</compression>
  </file>
  <fields>
    <field>
      <name>rating_id</name>
      <type>String</type>
      <position>-1</position>
      <length>100</length>
      <precision>-1</precision>
      <trim_type>none</trim_type>
      <repeat>N</repeat>
    </field>
    <!-- one field per CSV column -->
  </fields>
</transform>
```

## TextFileInput2 — JSONL

```xml
<separator>$[01]</separator>
<header>N</header>
<format>UNIX</format>
<file>
  <name>${STAGING_MOVIES_DIR}/</name>
  <filemask>exported_movies.json</filemask>
  <type>CSV</type>
  <compression>None</compression>
</file>
<fields>
  <field>
    <name>json_line</name>
    <type>String</type>
    <length>2000000</length>
    ...
  </field>
</fields>
```

## JsonInput (in-field)

```xml
<transform>
  <type>JsonInput</type>
  <name>Parse JSON documents</name>
  <valueField>json_line</valueField>
  <IsInFields>Y</IsInFields>
  <IsAFile>N</IsAFile>
  <removeSourceField>Y</removeSourceField>
  <ignoreMissingPath>Y</ignoreMissingPath>
  <fields>
    <field>
      <name>movie_id</name>
      <path>$.movie_id</path>
      <type>2</type>
    </field>
    <field>
      <name>runtime_minutes</name>
      <path>$.runtime_minutes</path>
      <type>5</type>
    </field>
  </fields>
</transform>
```

Type codes: `2` = String, `5` = Integer (Hop internal).

## Constant — batch_id

```xml
<transform>
  <type>Constant</type>
  <name>Add batch_id</name>
  <fields>
    <field>
      <name>batch_id</name>
      <type>String</type>
      <set_empty_string>N</set_empty_string>
      <value>${STAGING_BATCH_ID}</value>
    </field>
  </fields>
  <use_formatting>Y</use_formatting>
</transform>
```

## SetVariable — workflow variable

```xml
<transform>
  <type>SetVariable</type>
  <name>Set STAGING_BATCH_ID</name>
  <fields>
    <field>
      <field_name>batch_ts</field_name>
      <variable_name>STAGING_BATCH_ID</variable_name>
      <variable_type>PARENT_WORKFLOW</variable_type>
      <default_value>UNKNOWN_BATCH</default_value>
    </field>
  </fields>
  <use_formatting>Y</use_formatting>
</transform>
```

## TableOutput — staging

```xml
<transform>
  <type>TableOutput</type>
  <name>Insert into staging.stg_ratings</name>
  <connection>dw-staging</connection>
  <schema>staging</schema>
  <table>stg_ratings</table>
  <commit>100</commit>
  <use_batch>Y</use_batch>
  <specify_fields>Y</specify_fields>
  <fields>
    <field>
      <stream_name>rating_id</stream_name>
      <column_name>rating_id</column_name>
    </field>
  </fields>
</transform>
```

## Incremental extract SQL (PostgreSQL)

```sql
SELECT rating_id, user_id, movie_id, rating, rated_at, last_update_timestamp
FROM public.ratings
WHERE last_update_timestamp > '${RATING_LSET}'::timestamp
  AND last_update_timestamp <= '${RATING_CET}'::timestamp;
```

In XML, escape `<=` as `&lt;=`:

```xml
<sql>... last_update_timestamp &lt;= '${RATING_CET}'::timestamp;</sql>
```

## Control table update (ExecSQL)

```sql
UPDATE control.etl_extraction_control
SET lset = cet,
    cet = CURRENT_TIMESTAMP,
    last_run_status = 'SUCCESS',
    rows_extracted = ${RATING_ROWS_EXTRACTED},
    updated_at = CURRENT_TIMESTAMP
WHERE control_id = 1;
```

Set `replace_variables=Y` on the ExecSQL transform.

## Mongo ISO dates (TableInput — avoid Formula)

```sql
SELECT to_char(lset AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS movie_lset_iso,
       to_char(cet AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS movie_cet_iso
FROM control.etl_extraction_control
WHERE control_id = 3;
```

## Workflow hop (`.hwf`)

```xml
<hop>
  <from>00_init_staging_batch_id.hpl</from>
  <to>01_load_exported_ratings_to_staging.hpl</to>
  <evaluation>Y</evaluation>
  <unconditional>N</unconditional>
  <enabled>Y</enabled>
</hop>
```

## Pipeline order (`.hpl`)

```xml
<order>
  <hop>
    <from>Read exported_ratings.csv</from>
    <to>Trim string columns</to>
    <enabled>Y</enabled>
  </hop>
</order>
```

When generating XML programmatically, pass a **list** of hops to join — never `"\n".join(string)` on a single string.

## MDM operation reconcile

| Backend | NDS exists? | Staging operation |
|---------|-------------|-------------------|
| INSERT | No | INSERT |
| INSERT | Yes | UPDATE |
| UPDATE | Yes | UPDATE |
| UPDATE | No | INSERT |
| DELETE | Yes | DELETE |
| DELETE | No | 404 reject |

## MDM test curl

```bash
curl -u cluster:cluster -X POST \
  "http://127.0.0.1:8080/hop/webService/?service=mdm-users" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: local-dev-mdm-key" \
  -d '{"operation":"INSERT","sent_at":"2024-06-10T10:00:00.000Z","data":{"user_id":99,"username":"henry","email":"henry@movielens.local","age":30,"gender":"M","occupation":"analyst","created_at":"2024-06-10T10:00:00.000Z","last_update_timestamp":"2024-06-10T10:00:00.000Z"}}'
```

## NDS load order (recommended)

1. `stg_users` (MDM push — current state per user_id)
2. `stg_persons`, `stg_genres`, `stg_movies` (masters)
3. `stg_revenues`, `stg_ratings` (transactions — verify user_id / movie_id FKs)

## Verify SQL (after staging load)

```sql
SELECT 'stg_ratings' AS t, COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_ratings
UNION ALL SELECT 'stg_movies', COUNT(*), COUNT(DISTINCT batch_id) FROM staging.stg_movies;
```

Expect one distinct `batch_id` per workflow run across pull-loaded tables.
