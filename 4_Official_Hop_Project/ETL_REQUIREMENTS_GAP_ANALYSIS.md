# Đánh giá ETL theo yêu cầu đồ án BI

Ngày đánh giá baseline: 2026-07-17  
Phạm vi: `1_Project_Requirements/Requirement1.pdf` đến `Requirement6.pdf`, đối chiếu với `4_Official_Hop_Project` và trạng thái PostgreSQL local.  
Commit local tại thời điểm baseline: `f474b3fe6c6f817eff4ed3acd2eeec5ec3fe7b6e`

## 1. Kết luận baseline

ETL hiện tại đã vận hành được và đáp ứng phần lõi của Data Warehouse: Source → Staging → NDS → DDS, DQ, upsert, audit, cube và dashboard. Tuy nhiên, chưa đủ để kết luận đã đáp ứng toàn bộ yêu cầu đồ án.

Các khoảng trống quan trọng:

1. `Dim_Station` được đặt tên SCD Type 2 nhưng cấu hình thuộc tính hiện tại cập nhật dòng đang có, chưa thể hiện đầy đủ hành vi SCD2.
2. Chưa có cơ chế hoàn chỉnh cho master trạm đến trễ và reprocess trip chưa map được trạm.
3. LSET/CET đang phục vụ audit nhưng chưa được dùng để lọc incremental extraction thực tế.
4. Chưa có rule hoặc artifact kiểm tra data leak.
5. Chưa có phương pháp data mining; reporting mới thấy một dashboard chính.

Quy ước `net_flow` chính thức là `trips_ended - trips_started`; code DDS và SQL verification hiện đã đúng. `net_flow > 0` là xu hướng dồn ứ, `net_flow < 0` là xu hướng rút cạn.

### 1.1. Cập nhật sau checkpoint ưu tiên ngày 2026-07-17

Ba khoảng trống được xử lý trước và nối vào Workflow 01 ngay sau khi bốn nhánh source đã load/validate xong:

| Tiêu chí | Logic mới | Kết quả hiện tại | Phần chưa bao phủ |
|---|---|---|---|
| Phát hiện dữ liệu nguồn thay đổi | Fingerprint nội dung theo `source_name + source_file`, bỏ metadata ETL khỏi hash; lookup manifest để phân loại `NEW/CHANGED/UNCHANGED` | Đã có evidence bền vững trong `etl_source_file_manifest` và `etl_source_change_result` | Chưa skip file trước reader; chưa phát hiện file `MISSING`, schema header drift hoặc row bị xóa khỏi snapshot |
| Phát hiện đối tượng giống nhau | Đối chiếu station từ trip với GBFS trong cùng city theo ID, sau đó theo normalized name | `EXACT_ID` được chấp nhận; `NORMALIZED_NAME` và `UNMATCHED` luôn `requires_review=true` | Chưa có workflow người dùng duyệt candidate và chưa propagate quyết định xuống NDS |
| Kiểm tra data leak | Kiểm record sau ETL cutoff, trip kết thúc vượt train cutoff và thứ tự train/validation/test | Ghi `PASS/WARNING/FAIL` theo từng rule/run trong `etl_data_leak_rule_result` | Chưa thể thay thế feature-level leakage test vì data-mining pipeline chưa tồn tại |

Pipeline mới: `D_pipelines/01_ETL_Source_To_StagingDB/05_assess_source_change_matching_leakage.hpl`. Migration mới: `B_databases/B1_dw_stg_postgresql/05_etl_requirement_controls.sql`.

Validation fixture có rollback đã chứng minh:

- sửa `started_at` của cùng một raw row làm fingerprint đổi;
- entity matching trả đủ ba trạng thái `EXACT_ID`, `NORMALIZED_NAME`, `UNMATCHED`;
- một source row sau ETL cutoff trả `FAIL`;
- một trip vượt train cutoff trả `WARNING`;
- split cutoff đúng thứ tự trả `PASS`.

Do môi trường hiện không có `hop-run.sh`, pipeline chưa được thực thi bằng Hop CLI. XML/artifact tests đã pass và toàn bộ SQL lõi đã chạy thành công trực tiếp trên PostgreSQL local.

## 2. Đối chiếu sáu requirement

| Requirement | Tiêu chí | Logic/artifact đã có | Đánh giá baseline |
|---|---|---|---|
| Requirement 1 | Phân tích case study, chia nhỏ vấn đề, giải pháp từng vấn đề | Có người dùng cuối, sáu câu hỏi nghiệp vụ và KPI/measure tương ứng trong `official_topic.md` | Đạt phần lớn; cần diễn đạt rõ quyết định điều phối cho từng vấn đề |
| Requirement 2 | Input/output từng vấn đề; kiến trúc DW và lý do lựa chọn | Có ánh xạ nghiệp vụ → measure/dimension; có kiến trúc Source → Staging → NDS → DDS → Cube | Đạt một phần; input/output còn thể hiện gián tiếp |
| Requirement 3 | Ít nhất hai tầng NDS/DDS hoặc ODS/NDS/DDS; mô hình dữ liệu | Có raw/staging, NDS 3NF, DDS Snowflake, bốn dimension và một fact | Đạt về kiến trúc và artifact |
| Requirement 4 | Ít nhất ba nguồn; late master; upsert; source change; DQ; matching; leak | Có bốn nguồn, upsert, DQ, duplicate business key và audit | Chưa đạt đầy đủ: late master, change detection và leak còn thiếu/chưa hoàn chỉnh |
| Requirement 5 | Cube/hypercube, hierarchy, thao tác OLAP và MDX | Có Mondrian cube, hierarchy Time/City/Weather và MDX roll-up, drill-down, slice, dice, pivot | Đạt về artifact |
| Requirement 6 | Ít nhất hai report, trong đó có một dashboard; data mining | Có Tableau Executive Dashboard | Chưa đạt: chưa xác nhận report thứ hai và chưa có data-mining pipeline/minh họa |

## 3. Ma trận tiêu chí ETL và logic hiện có

| Tiêu chí ETL | Logic hiện có | Đánh giá baseline |
|---|---|---|
| Tách tầng DW | Raw 0NF → typed staging → NDS 3NF → DDS Snowflake | Đạt |
| Thứ tự master trước transaction | Workflow 02 load city/calendar → station → weather → trip | Đạt |
| Grain fact | Station × Hour; city suy ra qua station dimension | Đạt |
| Tổng hợp start/end | Full outer join theo station và giờ; tính trip started/ended, member/casual, loại xe | Đạt |
| Công thức `net_flow` | Pipeline và SQL test tính `trips_ended - trips_started`; tài liệu đã được đồng bộ theo cùng quy ước | Đạt |
| Upsert staging | Trip theo `(city_code, ride_id)`; weather theo city+hour; station theo city+short_name | Đạt |
| Upsert NDS | Trip theo `(city_sk, ride_id)`; weather theo city+hour | Đạt |
| Upsert fact | Theo `(station_sk, datetime_sk)` | Đạt |
| DQ | Null, duplicate, datatype, format; reject/warning chi tiết và tổng hợp | Đạt |
| Matching đối tượng giống nhau | Exact key `city + source_station_id`; ngăn join station cross-city | Đạt một phần; chưa có reconciliation/fuzzy matching hoặc hàng đợi review |
| SCD Type 2 station | Transform mang tên SCD2 nhưng thuộc tính dùng chế độ update; NDS update active row tại chỗ | Chưa đạt đầy đủ SCD2 |
| Fact gắn phiên bản SCD lịch sử | Fact lookup station với `is_current=true`, không lookup theo khoảng hiệu lực tại `date_hour` | Chưa đạt |
| Master đến trễ | Trip có thể vào NDS với `station_sk=NULL`; fact bỏ trip không map station | Chưa đạt |
| Ảnh hưởng late master trên DB local | 458.529 trip thiếu start station; 683.371 trip thiếu end station | Đang ảnh hưởng dữ liệu fact |
| Phát hiện dữ liệu nguồn thay đổi | Upsert ghi đè cùng business key; có LSET/CET | Đạt một phần; chưa có hash/checksum/source modified timestamp/change log |
| Incremental extraction | Đọc và cập nhật LSET/CET | Chưa đạt; chưa dùng watermark để lọc bản ghi/file đầu vào |
| Data leak | Không tìm thấy rule chia train/test theo thời gian, feature cutoff hoặc kiểm tra dữ liệu tương lai | Chưa đạt |
| Weather đến trễ/thiếu | Fact dùng `COALESCE` số đo về 0 và category về `Clear` | Chưa phù hợp; nên có `Unknown` hoặc reprocess |
| Audit và DQ gate | Có extraction control, job log, DQ result; Workflow 02 chặn source failed | Đạt |
| Portability | Dùng `${PROJECT_HOME}` và có portable-path test | Đạt |

## 4. Bằng chứng kiểm tra baseline

Các kiểm tra artifact đã chạy và pass:

- `tests/check_portable_paths.sh`
- `tests/check_staging_etl_artifacts.sh`
- `tests/check_staging_0nf_dq_artifacts.sh`
- `tests/check_nds_etl_artifacts.sh`
- `tests/check_runtime_counts.sh`

Trạng thái runtime local tại thời điểm đánh giá:

| Bảng | Số dòng |
|---|---:|
| `nds.city` | 2 |
| `nds.calendar_day` | 153 |
| `nds.station` | 4.473 |
| `nds.weather` | 7.193 |
| `nds.trip` | 16.294.520 |
| `dds.dim_station` | 4.473 |
| `dds.dim_datetime` | 5.088 |
| `dds.dim_weather_condition` | 4 |
| `dds.fact_station_hour_balance` | 5.250.568 |

Không phát hiện orphan fact hoặc duplicate current station trong DDS tại thời điểm kiểm tra.

## 5. Các phần cần fix theo data flow

### 5.1. Datasource → Raw Staging

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| Incremental extraction | Pipeline vẫn quét/truncate-load toàn bộ file; LSET/CET chưa lọc input | Chỉ đọc file hoặc record mới/thay đổi theo source modified time, manifest hoặc watermark phù hợp |
| Phát hiện source thay đổi | Chưa có checksum/hash/change log | Lưu `source_file`, kích thước, modified time, checksum và trạng thái new/changed/unchanged |
| File replay/idempotency | Rerun dựa chủ yếu vào upsert downstream | Có manifest kiểm soát file đã xử lý và cho phép replay có chủ đích |
| Source schema drift | Có field mapping nhưng chưa có rule/version schema riêng | Phát hiện thiếu/thừa/đổi kiểu cột trước khi load raw; ghi lỗi vào audit |

### 5.2. Raw Staging → Typed Staging

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| Entity matching/reconciliation | Chỉ exact match theo business key | Có rule chuẩn hóa ID/tên, phát hiện candidate giống nhau và hàng đợi review nếu không thể quyết định tự động |
| DQ coverage | Đã có null, duplicate, datatype, format | Bổ sung referential/business consistency, boundary bất thường và thống kê tỷ lệ reject/warning theo batch |
| DQ gate | Có DQ result và gate tổng quát | Định nghĩa threshold rõ cho từng source/rule; vượt threshold thì fail, không chỉ dựa vào có/không accepted row |
| Change evidence | Upsert ghi đè nhưng không lưu bằng chứng field nào đổi | Ghi old/new value hoặc change hash cho các business key thay đổi |

### 5.3. Typed Staging → NDS

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| Late-arriving station master | Trip có thể được lưu với `station_sk=NULL` | Tạo unknown/skeleton station hoặc suspense/backlog để không mất khả năng tổng hợp |
| Reprocess station mapping | Khi GBFS đến sau, trip cũ chưa tự lookup lại station | Có job resolve lại `start_station_sk/end_station_sk`, ghi affected business grain cho DDS reload |
| NDS station history | UPDATE ghi đè active row tại chỗ | Chốt rõ NDS dùng Type 1 hay lưu version; nếu DDS cần SCD2 thì phải cung cấp change timestamp và old/new state đáng tin cậy |
| Incremental NDS load | Trip upsert theo key nhưng vẫn phụ thuộc full staging input | Chỉ xử lý accepted row của batch/change set hiện tại và audit insert/update/no-op riêng |
| Cleanup staging | Cleanup sau NDS thành công | Giữ manifest/audit/reject đủ để replay; cleanup không làm mất bằng chứng nguồn |

### 5.4. NDS → DDS

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| SCD2 effective dating | Remote đổi attribute sang `Insert` nhưng gán `effective_from = 1900-01-01` | Version mới dùng đúng thời điểm thay đổi; version cũ được đóng chính xác, không overlap/gap ngoài chủ đích |
| Fact lookup station version | Remote đã lookup theo `date_hour` | Giữ logic này, nhưng chỉ xem là đúng sau khi effective dating của dimension đúng |
| Incremental affected grain | Remote lọc trip theo `loaded_at`, rồi chỉ aggregate trip mới | Dùng change set để tìm `(city, station, business_hour)` bị ảnh hưởng, sau đó aggregate lại toàn bộ trip của các grain đó |
| Delete/upsert fact | Remote xóa theo khoảng thời gian ETL rồi `TableOutput` | Delete+insert đúng affected business grain hoặc dùng upsert idempotent; không trộn ETL time với business time |
| Late weather | Weather thiếu bị gán số đo `0` và category `Clear` | Dùng `Unknown`/NULL và reprocess affected fact khi NOAA đến |
| Runtime reconciliation | Static test chưa kiểm tổng incremental | Thêm test first load, no-op rerun, late trip, changed trip, late weather, late station và đối chiếu full rebuild |

### 5.5. DDS → Cube/Reporting

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| `net_flow` semantics | Code đúng `ended - started`; tài liệu trước đây có chỗ ghi ngược | Toàn bộ report dùng dương = dồn ứ, âm = rút cạn; tooltip/legend phải nói rõ |
| Report coverage | Mới xác nhận một Executive Dashboard | Có ít nhất report thứ hai độc lập, ví dụ Station Rebalancing Detail/Alert Report |
| Cube reconciliation | Có MDX và hierarchy | Có SQL đối chiếu từng MDX demo với DDS sau incremental load |
| Data freshness | Chưa thể hiện watermark trên dashboard | Hiển thị last successful ETL time và cảnh báo dữ liệu thiếu/late |

### 5.6. DDS → Data Mining

| Nhóm fix | Hiện trạng | Kết quả cần đạt |
|---|---|---|
| Phương pháp khai thác dữ liệu | Chưa có artifact | Chọn bài toán khả thi, ví dụ dự báo `abs_imbalance` hoặc phân cụm station-hour |
| Data leak | Chưa có rule/cutoff | Split train/validation/test theo thời gian; feature chỉ dùng dữ liệu có sẵn trước thời điểm dự báo |
| Feature lineage | Chưa mô tả | Ghi rõ feature lấy từ dimension/fact nào, cutoff nào và target horizon nào |
| Minh họa/đánh giá | Chưa có | Có notebook/pipeline, metric baseline và một visualization phục vụ Requirement 6 |

## 6. So sánh với remote

Đã fetch ngày 2026-07-17, không merge vào working tree.

- Local `HEAD`: `f474b3fe6c6f817eff4ed3acd2eeec5ec3fe7b6e`
- `origin/master`: `aed566a3a85d96218c5a43959d1bd5de729047c3`
- Remote đi trước local: 11 commit
- Phạm vi thay đổi: 19 file, chủ yếu ở Workflow 02/03 và NDS → DDS incremental/SCD

### 6.1. Những thay đổi tích cực trên remote

1. Thêm `00_start_etl_nds_to_dds.hpl` để đọc watermark `LSET_NDS_TO_DDS` và `CET_NDS_TO_DDS`.
2. Thêm `05_audit_nds_to_dds.hpl` để cập nhật `control.etl_extraction_control` và ghi `control.etl_job_log`.
3. Thêm control row `nds_to_dds / fact_station_hour_balance`.
4. `D2_Load_Dim_Station.hpl` đổi các thuộc tính station từ chế độ `Update` sang `Insert`, phù hợp hơn với SCD Type 2.
5. Fact station lookup đổi từ lookup dòng `is_current=true` sang `DimensionLookup` theo `date_hour` và khoảng `effective_from/effective_to`.
6. Thêm index NDS phục vụ aggregate theo station-hour.
7. Thêm bước xóa fact range, batch `TableOutput`, cache lookup và audit để tối ưu Workflow 03.
8. Thêm workflow `00_unify_all_workflows.hwf` để nối các workflow thành luồng tổng.

### 6.2. Đối chiếu lại các tiêu chí còn thiếu

| Tiêu chí baseline | Thay đổi trên `origin/master` | Kết luận sau fetch |
|---|---|---|
| Quy ước `net_flow` | Remote tính `trips_ended - trips_started`, đúng theo quy ước chính thức | Code đúng; tài liệu local đã đồng bộ |
| SCD Type 2 station | Attribute đã đổi sang `Insert`; fact lookup theo effective date | Fix một phần |
| Effective date SCD | D2 đang gán mọi active station `effective_from = 1900-01-01`; NDS vẫn update active row tại chỗ | Chưa đúng hoàn toàn; version boundary có nguy cơ sai |
| Fact gắn phiên bản station lịch sử | Đã dùng `DimensionLookup` theo `date_hour` | Đã cải thiện, nhưng phụ thuộc effective date SCD đúng |
| Late-arriving station master | Trip load vẫn lookup current station; không có skeleton/unknown/backlog/reprocess | Chưa fix |
| Trip chưa map station | D3 vẫn loại `start_station_sk IS NULL` và `end_station_sk IS NULL` | Chưa fix |
| Incremental Source → Staging | Source load vẫn truncate/read toàn bộ file; chưa lọc bằng LSET/CET | Chưa fix |
| Incremental NDS → DDS | Đã lọc `nds.*.loaded_at` theo LSET/CET và có audit watermark | Có triển khai nhưng logic chưa an toàn |
| Rebuild affected fact grain | D3 chỉ aggregate các trip mới load, không aggregate lại toàn bộ station-hour bị ảnh hưởng | Chưa đạt |
| Xóa fact trước incremental insert | Workflow xóa fact theo khoảng `datetime_sk` suy ra từ thời gian chạy LSET/CET, trong khi business date của trip là 01–05/2026 | Có nguy cơ không xóa đúng grain và gây unique conflict hoặc làm sai tổng |
| Phát hiện source thay đổi | Không có hash/checksum/source modified time/change log | Chưa fix |
| DQ và matching | Không thêm rule matching/reconciliation mới | Không thay đổi đáng kể |
| Data leak | Không có rule hoặc data-mining split/cutoff | Chưa fix |
| Weather thiếu | Vẫn `COALESCE` số đo về 0 và category về `Clear` | Chưa fix |
| Report thứ hai/data mining | Remote không thay đổi `G_reporting` hay thêm data-mining artifact | Chưa fix |

### 6.3. Rủi ro mới của incremental NDS → DDS

Remote đã thêm incremental nhưng chưa thể xem là hoàn tất vì:

1. Watermark dựa trên `loaded_at`/thời gian chạy, còn bước `Clean fact range` lại chuyển chính LSET/CET đó thành `datetime_sk`. Hai khái niệm thời gian khác nhau: thời gian nạp ETL và thời gian nghiệp vụ của chuyến đi.
2. Một trip đến muộn có thể có `loaded_at` trong lần chạy hiện tại nhưng `started_at` thuộc tháng cũ. Bước xóa range có thể không xóa fact tháng cũ trước khi `TableOutput` insert, dẫn đến trùng unique key.
3. D3 chỉ tổng hợp các trip có `loaded_at` trong cửa sổ mới. Nếu xóa một station-hour cũ rồi chỉ insert phần trip mới, tổng fact sẽ thiếu các trip đã nạp ở các batch trước.
4. Target được đổi từ `InsertUpdate` sang `TableOutput`, nên tính idempotent phụ thuộc hoàn toàn vào việc xác định và xóa đúng affected grain.

Hướng đúng nên là: dùng watermark để xác định tập `(city, station, business_hour)` bị ảnh hưởng, sau đó aggregate lại **toàn bộ** trip của các grain đó và upsert hoặc delete+insert chính xác theo grain.

### 6.4. Kiểm tra tĩnh phiên bản remote

Đã checkout `origin/master` vào worktree tạm, không merge, và chạy:

- `check_portable_paths.sh`: pass
- `check_staging_etl_artifacts.sh`: pass
- `check_staging_0nf_dq_artifacts.sh`: pass
- `check_nds_etl_artifacts.sh`: pass
- `xmllint --noout` cho Workflow và pipeline 03: pass
- `validate-hpl.sh` cho năm pipeline NDS → DDS: pass

Các test hiện tại xác nhận cấu trúc/XML/artifact hợp lệ, nhưng chưa kiểm chứng tính đúng của incremental aggregate, late master hoặc SCD effective dating. Chưa chạy Workflow 03 của remote trên database local vì remote chưa được merge và database hiện tại vẫn thuộc baseline local.

## 7. Kết luận sau khi fetch

Remote đã **cải thiện rõ phần orchestration, audit và ý tưởng incremental/SCD**, nhưng chưa fix đủ các tiêu chí quan trọng của Requirement 4. Trạng thái tổng thể vẫn là **đạt một phần**.

Không nên merge và xem là hoàn tất ngay. Trước tiên cần sửa hoặc chứng minh bằng runtime test các điểm:

1. Datasource → Staging: incremental extraction, source manifest/checksum và schema-drift detection.
2. Staging → NDS: late-arriving master, reprocess station mapping và change evidence.
3. NDS → DDS: effective dating SCD2, incremental fact theo affected business grain và weather unknown.
4. DDS → Cube/Reporting: report thứ hai, data freshness và reconciliation.
5. DDS → Data Mining: phương pháp mining, temporal split và data-leak controls.
