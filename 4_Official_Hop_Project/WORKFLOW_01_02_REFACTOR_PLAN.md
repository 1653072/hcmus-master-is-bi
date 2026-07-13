# Execution Plan — Refactor Workflow 01 và 02

## Mục tiêu

- Workflow 01: đổi nhánh accepted Citi Bike từ `ExecSql` upsert sang `TableInput -> InsertUpdate`; filter, deduplicate và cast trong `TableInput`, không dùng JavaScript.
- Workflow 02: gộp ba pipeline trip thành một pipeline Hop-native, dùng lookup và `InsertUpdate`, bỏ `import.stg_trip`.
- Đánh lại số pipeline Workflow 02 và đồng bộ workflow, DDL, fallback script, tests, README.

## Quy tắc chạy checkpoint

1. Mỗi block là đúng **một lần chạy**.
2. Mỗi lần chỉ chạy block `[ ]` đầu tiên; không làm trước block tiếp theo.
3. Kiểm tra Git status trước khi sửa và giữ nguyên thay đổi ngoài phạm vi block.
4. Phải chạy hết mục **Validation** trước khi tick `[x]`.
5. Validation fail: giữ `[ ]`, ghi nhật ký/blocker, báo người dùng và dừng.
6. Validation pass: tick `[x]`, cập nhật nhật ký, báo kết quả và **dừng chờ người dùng cho tiếp tục**.
7. Không tự stage, commit, push hoặc chạy block kế tiếp.
8. Không tuyên bố tăng hiệu năng nếu chưa benchmark cùng dataset và điều kiện.

## Tiến độ

- [x] Block 01 — Baseline và chốt mapping
- [x] Block 02 — Refactor Citi Bike accepted load của Workflow 01
- [x] Block 03 — Runtime proof Workflow 01 trên một tháng
- [x] Block 04 — Tạo pipeline trip Hop-native mới cho Workflow 02
- [x] Block 05 — Tích hợp pipeline trip mới vào Workflow 02
- [x] Block 06 — Xóa `import.stg_trip` và buffer artifacts
- [x] Block 07 — Đánh lại số pipeline Workflow 02
- [x] Block 08 — Đồng bộ fallback script, tests và README
- [x] Block 09 — Runtime proof và idempotency Workflow 02
- [x] Block 10 — Final regression và tổng kết

---

## [x] Block 01 — Baseline và chốt mapping

### Triển khai

- Ghi nhận Git status và các lỗi baseline có sẵn.
- Đọc hai workflow, pipeline Citi validate và ba pipeline trip/buffer hiện tại.
- Chốt mapping trong nhật ký block:
  - staging key: `source_city_code + ride_id`;
  - NDS key: `city_sk + ride_id`;
  - city lookup: `source_city_code -> city_sk`;
  - station lookup: `city_sk + source_station_id + is_current=TRUE`;
  - city không map: reject/filter; station không map: cho phép `station_sk=NULL`;
  - duplicate: deduplicate xác định trước `InsertUpdate`;
  - duration không hợp lệ: `NULL`.
- Không sửa logic ETL trong block này.

### Validation

```bash
cd 4_Official_Hop_Project
bash tests/check_staging_etl_artifacts.sh
bash tests/check_staging_0nf_dq_artifacts.sh
bash tests/check_nds_etl_artifacts.sh
xmllint --noout E_workflows/01_etl_source_to_stagingdb.hwf
xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf
```

### Gate hoàn thành

- Baseline/mapping đã ghi; phân biệt được lỗi có sẵn với regression.
- Validation đạt hoặc lỗi có sẵn được chứng minh rõ.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày: 2026-07-13
- Git status: Không có thay đổi tracked; chỉ có file plan này ở trạng thái untracked trước và sau block.
- Mapping/baseline:
  - Workflow 01 gọi `02_validate_citibike_raw_to_staging.hpl` sau Citi Bike raw load; pipeline hiện có hai nhánh `TableInput -> TableOutput` cho DQ và một `ExecSql` set-based upsert vào `staging.stg_citibike_trips`.
  - Staging business key là `source_city_code + ride_id`.
  - Workflow 02 hiện chạy tuần tự city/calendar -> GBFS station -> weather -> prepare buffer -> load buffer -> merge buffer -> audit -> cleanup buffer -> cleanup staging.
  - `import.stg_trip` là UNLOGGED transient buffer trong `dw_nds`; pipeline cũ bulk copy từ staging vào buffer rồi `ExecSql` merge sang `nds.trip`.
  - NDS business key là `city_sk + ride_id`; `trip_sk` là surrogate primary key, không được map bởi pipeline upsert.
  - City lookup cần `source_city_code -> city_sk`; station lookup cần `city_sk + source_station_id + is_current=TRUE` để tránh map chéo thành phố.
  - City không map phải bị filter/reject trước target; station không map có thể giữ `station_sk=NULL`; duplicate phải deduplicate xác định trước InsertUpdate; `ended_at` null hoặc nhỏ hơn `started_at` cho `duration_minutes=NULL`.
- Validation:
  - PASS: `bash tests/check_staging_etl_artifacts.sh`
  - PASS: `bash tests/check_staging_0nf_dq_artifacts.sh`
  - PASS: `bash tests/check_nds_etl_artifacts.sh`
  - PASS: `xmllint --noout E_workflows/01_etl_source_to_stagingdb.hwf`
  - PASS: `xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf`
  - PASS: `git diff --check` (không có tracked diff tại thời điểm baseline)
- Blocker: Không có.

---

## [x] Block 02 — Refactor Citi Bike accepted load của Workflow 01

### Triển khai

- Chỉ sửa `D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl` và test artifact trực tiếp nếu cần.
- Giữ nguyên nhánh DQ details và DQ summary.
- Thay transform `ExecSql` upsert bằng:

```text
TableInput: Read valid typed Citi Bike trips
  -> InsertUpdate: Upsert staging.stg_citibike_trips
```

- `TableInput` phải hỗ trợ `CITIBIKE_VALIDATE_MONTH`, trim/null normalization, guard trước cast, `DISTINCT ON (source_city_code, ride_id)` với thứ tự ổn định, và trả đúng type target.
- `InsertUpdate` dùng connection `dw-staging`, table `staging.stg_citibike_trips`, key `source_city_code + ride_id`; không cập nhật key, không dùng JavaScript.

### Validation

```bash
/Users/huynguyen/.codex/skills/bi-hop-etl/scripts/validate-hpl.sh 4_Official_Hop_Project/D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl
xmllint --noout 4_Official_Hop_Project/D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl
cd 4_Official_Hop_Project
bash tests/check_staging_etl_artifacts.sh
bash tests/check_staging_0nf_dq_artifacts.sh
git diff --check
```

- Kiểm tra tĩnh: không còn accepted-row `ExecSql`; có đúng hop `TableInput -> InsertUpdate`; không có `ScriptValueMod` trong nhánh mới; field/key mapping khớp schema.

### Gate hoàn thành

- Static validation đạt; chưa chạy full Workflow 01.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày: 2026-07-13
- File đổi:
  - `D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl`
  - `tests/check_staging_etl_artifacts.sh`
- Thay đổi:
  - Giữ nguyên hai nhánh DQ detail/summary.
  - Thay transform accepted-row `ExecSql` bằng `Read valid typed Citi Bike trips` (`TableInput`) nối đến `Upsert staging.stg_citibike_trips` (`InsertUpdate`).
  - SQL TableInput vẫn filter theo `CITIBIKE_VALIDATE_MONTH`, chuẩn hóa empty string, `DISTINCT ON (source_city_code_norm, ride_id_norm)`, cast typed fields và tạo `loaded_at`.
  - InsertUpdate dùng key `source_city_code + ride_id`; hai key không update, các thuộc tính nghiệp vụ và `loaded_at` được update; commit size là `10000`.
  - Artifact test đổi từ yêu cầu set-based `ExecSql` sang yêu cầu Hop `TableInput -> InsertUpdate` và cấm `ScriptValueMod`.
- Validation:
  - PASS: `validate-hpl.sh D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl`
  - PASS: `xmllint --noout D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl`
  - PASS: `bash tests/check_staging_etl_artifacts.sh`
  - PASS: `bash tests/check_staging_0nf_dq_artifacts.sh`
  - PASS: static check xác nhận không còn `ExecSql`/`ScriptValueMod` và hop mới cùng key update `N`.
  - PASS: `git diff --check`
- Blocker: Không có. Chưa chạy dữ liệu thật; runtime proof thuộc Block 03.

---

## [x] Block 03 — Runtime proof Workflow 01 trên một tháng

### Triển khai

- Chạy pipeline Citi với tháng đại diện `202602` và load-run ID riêng.
- Thu input/accepted/reject/warning count, duplicate count, runtime và lỗi.
- Rerun cùng tháng để kiểm tra idempotency.
- Chỉ sửa lỗi trực tiếp từ Block 02; thay đổi thiết kế lớn phải dừng xin ý kiến.

### Validation

- Hop pipeline success; không lỗi cast.
- Không duplicate `(source_city_code, ride_id)`.
- Rerun không tăng row count bất thường; DQ evidence đúng load-run ID.
- Chạy lại hai artifact tests của staging và `git diff --check`.

### Gate hoàn thành

- Runtime proof và idempotency đạt; ghi runtime nhưng không kết luận nhanh hơn bản cũ.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/tháng/load-run ID: 2026-07-13 / 202602 / `refactor_202602_20260713_run1`, `refactor_202602_20260713_run2`
- Counts/runtime:
  - Docker `dw-stg`, `dw-nds`, `dw-dds` đều healthy.
  - Hop 2.18.1 đã được cài local ngoài repo, checksum SHA-512 và archive integrity đã xác nhận.
  - Raw loader Hop đã nạp `1,219,444` rows tháng `202602` vào `staging.raw_citibike_trips`.
  - Lần chạy 1 của pipeline refactor thành công: `1,219,273` accepted/staging rows, `1,219,273` distinct business keys, runtime `632.501s`.
  - Lần chạy 2 hoàn tất thành công: `1,219,273` input rows, `0` inserted rows, `1,219,273` update-bypassed rows, runtime `736.547s`; staging row count vẫn là `1,219,273`.
  - Source month `202602` có sẵn local: ZIP `A_datasets/A1_citibike/202602-citibike-tripdata.zip` và hai CSV tại `A_datasets/A1_citibike/extracted/202602/`. Pipeline raw loader trỏ `${CITIBIKE_TRIPS_DIR}` vào `A1_citibike/extracted` với `include_subfolders=Y`, nên sẽ đọc đúng hai file này.
  - Kết luận trước đó “không có file Citi Bike 202602” là sai vì `rg --files` mặc định tôn trọng `.gitignore`; `A_datasets/.gitignore` bỏ qua file ZIP dataset. Không dùng Git-aware file discovery để kết luận dataset local không tồn tại nữa.
  - Theo xác nhận của người dùng, validation mẫu `202602` trước đây đã có khoảng `1,219,706` accepted rows; số này là historical context, không phải kết quả của refactor hiện tại.
  - Không có runtime hoặc rerun idempotency vì chưa có lần chạy Hop.
  - DQ result còn lại từ lần chạy cũ (`bootstrap_202601_202605`) không thể dùng để chứng minh refactor mới.
- Validation:
  - PASS: `validate-hpl.sh D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl`
  - PASS: `xmllint --noout D_pipelines/01_ETL_Source_To_StagingDB/02_validate_citibike_raw_to_staging.hpl`
  - PASS: `bash tests/check_staging_etl_artifacts.sh`
  - PASS: `bash tests/check_staging_0nf_dq_artifacts.sh`
  - PASS: `git diff --check`
- Blocker: Không có. Idempotency được chứng minh bằng Hop completion của run 2, staging row count không đổi và duplicate business key = `0`.

---

## [x] Block 04 — Tạo pipeline trip Hop-native mới cho Workflow 02

### Triển khai

- Tạo `D_pipelines/02_ETL_StagingDB_To_NDS/04_load_trips_to_nds.hpl`; chưa đổi workflow và chưa xóa pipeline cũ.
- Luồng:

```text
TableInput: read + deduplicate Divvy/Citi staging
  -> DBLookup city_sk
  -> FilterRows mapped city
  -> DBLookup start_station_sk scoped by city
  -> DBLookup end_station_sk scoped by city
  -> Calculator/Formula hoặc SQL expression cho duration_minutes
  -> InsertUpdate nds.trip
```

- Key target `city_sk + ride_id`; không map `trip_sk`.
- City không map bị filter rõ ràng; station không map được phép null.
- `duration_minutes=NULL` khi thiếu `ended_at` hoặc `ended_at < started_at`.

### Validation

```bash
/Users/huynguyen/.codex/skills/bi-hop-etl/scripts/validate-hpl.sh 4_Official_Hop_Project/D_pipelines/02_ETL_StagingDB_To_NDS/04_load_trips_to_nds.hpl
xmllint --noout 4_Official_Hop_Project/D_pipelines/02_ETL_StagingDB_To_NDS/04_load_trips_to_nds.hpl
cd 4_Official_Hop_Project
git diff --check
```

- Kiểm tra tĩnh: không có `import.stg_trip`; có city + hai station lookup; station lookup scope theo city; đúng `InsertUpdate` key; không JavaScript.

### Gate hoàn thành

- Pipeline mới đạt static validation; workflow/pipeline cũ chưa đổi.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/file đổi: 2026-07-13 / `D_pipelines/02_ETL_StagingDB_To_NDS/04_load_trips_to_nds.hpl`
- Validation: PASS `validate-hpl.sh`; PASS `xmllint`; PASS `git diff --check`.
- Blocker: Không có. Pipeline mới chưa được nối vào workflow hoặc chạy runtime; đó là Block 05/09.

---

## [x] Block 05 — Tích hợp pipeline trip mới vào Workflow 02

### Triển khai

- Sửa `E_workflows/02_etl_stagingdb_to_nds.hwf`:
  - bỏ actions/hops prepare, bulk buffer, merge và cleanup buffer;
  - thêm một action gọi `04_load_trips_to_nds.hpl`;
  - giữ `wait_until_finished=Y`, `pass_all_parameters=Y`;
  - nối `weather -> trip -> audit -> cleanup staging`.
- Giữ file/DDL buffer đến Block 06.
- Sửa artifact test tối thiểu để phản ánh workflow graph mới.

### Validation

```bash
cd 4_Official_Hop_Project
xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf
bash tests/check_nds_etl_artifacts.sh
git diff --check
```

- Không còn action/hop buffer trong workflow; có đúng một trip action; audit sau trip; cleanup staging sau audit.

### Gate hoàn thành

- Workflow graph và artifact test đạt; chưa cleanup diện rộng.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/file đổi: 2026-07-13 / `E_workflows/02_etl_stagingdb_to_nds.hwf`, `tests/check_nds_etl_artifacts.sh`
- Validation: Workflow graph `weather -> trip -> audit -> cleanup`; `xmllint`, artifact test và `git diff --check` PASS.
- Blocker: Không có.

---

## [x] Block 06 — Xóa `import.stg_trip` và buffer artifacts

### Triển khai

- Xóa `03_prepare_trip_buffer.hpl`, trip-buffer version cũ của `03_load_trips_to_nds.hpl`, `03_merge_trip_buffer_to_nds.hpl`, `05_cleanup_nds_trip_buffer.hpl` và `B_databases/B2_dw_nds_postgresql/05_import_trip_buffer.sql`.
- Xóa dependency trip buffer trong DDL/tests; không xóa schema/import artifacts của station hoặc weather.
- Chưa rename pipeline còn lại.

### Validation

```bash
cd 4_Official_Hop_Project
! rg -n 'import\.stg_trip|03_prepare_trip_buffer|03_merge_trip_buffer_to_nds|05_cleanup_nds_trip_buffer' B_databases D_pipelines E_workflows tests
bash tests/check_nds_etl_artifacts.sh
xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf
git diff --check
```

### Gate hoàn thành

- Không còn trip-buffer artifact/reference; không xóa nhầm station/weather import.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/file xóa-đổi: 2026-07-13 / xóa 4 pipeline buffer và `05_import_trip_buffer.sql`; drop live table `import.stg_trip`.
- Validation: Không còn trip-buffer artifact trong DDL/pipeline/workflow; artifact verifier PASS.
- Blocker: Không có.

---

## [x] Block 07 — Đánh lại số pipeline Workflow 02

### Triển khai

```text
01_load_city_calendar_to_nds.hpl        giữ nguyên
01_load_gbfs_station_to_nds.hpl         -> 02_load_gbfs_station_to_nds.hpl
02_load_weather_to_nds.hpl              -> 03_load_weather_to_nds.hpl
04_load_trips_to_nds.hpl                giữ nguyên
04_audit_stagingdb_to_nds_job_log.hpl   -> 05_audit_stagingdb_to_nds_job_log.hpl
05_cleanup_staging_after_nds.hpl        -> 06_cleanup_staging_after_nds.hpl
```

- Cập nhật `<name>` trong `.hpl`, filename/action/hop trong workflow và test reference trực tiếp.
- README/fallback script diện rộng để Block 08.

### Validation

```bash
/Users/huynguyen/.codex/skills/bi-hop-etl/scripts/validate-hpl.sh 4_Official_Hop_Project/D_pipelines/02_ETL_StagingDB_To_NDS/*.hpl
cd 4_Official_Hop_Project
xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf
bash tests/check_nds_etl_artifacts.sh
git diff --check
```

- Không còn tên cũ trong pipelines/workflow/tests; filename khớp `<name>`; order là city/calendar → station → weather → trip → audit → cleanup.

### Gate hoàn thành

- Rename/reference kỹ thuật đạt validation.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/file rename-đổi: 2026-07-13 / station `02`, weather `03`, trip `04`, audit `05`, cleanup `06`; internal names và workflow references đồng bộ.
- Validation: `validate-hpl.sh`, workflow XML, artifact test và `git diff --check` PASS.
- Blocker: Không có.

---

## [x] Block 08 — Đồng bộ fallback script, tests và README

### Triển khai

- Refactor `scripts/run_staging_to_nds.sh` bỏ trip buffer nhưng giữ cùng semantics: deduplicate, city-scoped station lookup, nullable station SK, duration rule, upsert key.
- Cập nhật `check_nds_etl_artifacts.sh`, `check_runtime_counts.sh`, test liên quan và README.
- README mô tả Hop-native pipeline mới và không tuyên bố tối ưu hiệu năng chưa benchmark.

### Validation

```bash
cd 4_Official_Hop_Project
! rg -n 'import\.stg_trip|03_prepare_trip_buffer|03_merge_trip_buffer_to_nds|05_cleanup_nds_trip_buffer|01_load_gbfs_station_to_nds|02_load_weather_to_nds|04_audit_stagingdb_to_nds_job_log|05_cleanup_staging_after_nds' README.md scripts tests D_pipelines E_workflows B_databases
bash -n scripts/run_staging_to_nds.sh
bash tests/check_staging_etl_artifacts.sh
bash tests/check_staging_0nf_dq_artifacts.sh
bash tests/check_nds_etl_artifacts.sh
tests/check_portable_paths.sh
git diff --check
```

### Gate hoàn thành

- Hop workflow, fallback, tests và README cùng kiến trúc; không stale reference.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/file đổi: 2026-07-13 / `scripts/run_staging_to_nds.sh`, NDS artifact/runtime tests, `README.md`.
- Validation: shell syntax, artifact suites, portable paths và `git diff --check` PASS; README không tuyên bố performance chưa benchmark.
- Blocker: Không có.

---

## [x] Block 09 — Runtime proof và idempotency Workflow 02

### Triển khai

- Xác nhận DB healthy và có staging data/fixture đại diện; ghi counts trước chạy.
- Chạy Hop Workflow 02 thật, kiểm tra NDS counts, duplicate key, city/station mapping, duration, audit và cleanup.
- Chuẩn bị lại cùng input và rerun kiểm tra idempotency; ghi runtime hai lần.

### Validation

```bash
cd 4_Official_Hop_Project
make db-status
make nds-load
make runtime-checks
git diff --check
```

- Nếu `make nds-load` fallback sang shell do thiếu Hop CLI thì không tính là proof `.hwf`; giữ `[ ]` trừ khi người dùng chấp nhận proof thay thế.

### Gate hoàn thành

- Hop Workflow 02 success; invariants/counts đạt; rerun không duplicate/tăng sai; audit/cleanup đúng.
- Tick block, ghi nhật ký, báo người dùng và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày/dataset: 2026-07-13 / Citi Bike `202602`; input staging deduplicated `1,219,273` rows.
- Counts/runtime:
  - Baseline NDS: `16,294,520` trip rows, duplicate `(city_sk, ride_id)` = `0`, `import.stg_trip` = không tồn tại.
  - Pipeline `04_load_trips_to_nds.hpl` run 1: exit `0`, upsert `1,219,273` rows, `549.9s`.
  - Cùng input run 2: exit `0`, upsert `1,219,273` rows, `543.44s`; tổng NDS vẫn `16,294,520`, duplicate key vẫn `0`.
  - Full Workflow 02: exit `0`, `551.903s`; action sequence kết thúc `04 trip -> 05 audit -> 06 cleanup -> Success`.
  - Audit mới nhất: `log_id=36`, status `SUCCESS`, total/success/failed = `1,219,302 / 1,219,302 / 0`.
  - Hậu kiểm: duplicate key `0`, duration mismatch `0`, station-city mismatch `0`, buffer table `0`; toàn bộ raw/staging trip, weather và station tables đã cleanup về `0`.
- Validation: `make db-status` PASS (3 containers healthy); `tests/check_runtime_counts.sh` PASS; Hop CLI project `hcmus-bi`, environment `dev`, local engine.
- Blocker: Không.

---

## [x] Block 10 — Final regression và tổng kết

### Triển khai

- Review toàn bộ diff; không thêm feature.
- Kiểm tra file thừa, stale reference, đường dẫn cá nhân, XML và portability.
- Chạy full static/artifact regression; runtime checks chỉ khi DB ở đúng post-success state.
- Không stage/commit/push nếu người dùng chưa yêu cầu.

### Validation

```bash
/Users/huynguyen/.codex/skills/bi-hop-etl/scripts/validate-hpl.sh 4_Official_Hop_Project/D_pipelines/01_ETL_Source_To_StagingDB/*.hpl 4_Official_Hop_Project/D_pipelines/02_ETL_StagingDB_To_NDS/*.hpl
cd 4_Official_Hop_Project
xmllint --noout E_workflows/01_etl_source_to_stagingdb.hwf
xmllint --noout E_workflows/02_etl_stagingdb_to_nds.hwf
bash tests/check_staging_etl_artifacts.sh
bash tests/check_staging_0nf_dq_artifacts.sh
bash tests/check_nds_etl_artifacts.sh
tests/check_portable_paths.sh
git diff --check
```

### Gate hoàn thành

- Blocks 01–09 đã `[x]`; final regression đạt; không stale reference/buffer artifact.
- Tick block, báo tổng kết và dừng.

### Nhật ký

- Trạng thái: Hoàn thành
- Ngày: 2026-07-13
- Validation/runtime proof:
  - `validate-hpl.sh` PASS cho Workflow 01 và toàn bộ pipeline Workflow 02; các warning TextFileInput2 ở loader cũ không thuộc phạm vi refactor và pipeline Citi refactor báo `OK`.
  - `xmllint --noout` PASS cho cả hai workflow.
  - `check_staging_etl_artifacts.sh`, `check_staging_0nf_dq_artifacts.sh`, `check_nds_etl_artifacts.sh`, `check_portable_paths.sh` và `check_runtime_counts.sh` đều PASS.
  - Không còn stale reference tới pipeline/buffer cũ ngoài nội dung lịch sử của plan và negative assertions trong tests; không có đường dẫn `/Users/huynguyen` trong runtime artifacts.
  - `git diff --check` PASS.
- Git status cuối: Các thay đổi vẫn để nguyên unstaged; không stage/commit/push theo đúng phạm vi được giao.
- Blocker: Không.

---

## Mẫu báo cáo sau mỗi block

```text
Đã hoàn thành Block XX — <tên block>.

Đã thay đổi:
- <file/thay đổi chính>

Validation:
- PASS: <lệnh/kết quả>

Plan đã tick [x] Block XX.
Đã dừng tại đây. Chờ bạn kiểm tra và yêu cầu tiếp tục Block YY.
```

Nếu thất bại:

```text
Block XX chưa hoàn thành và vẫn giữ [ ].
FAIL: <validation/kết quả>
Blocker: <nguyên nhân>.
Đã dừng, chưa thực hiện Block YY.
```
