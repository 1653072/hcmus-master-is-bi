# 4_Official_Hop_Project — shortcuts (chạy từ thư mục này)
#   make help
#   make datasets-check
#   make datasets-full

SAMPLE_YEAR ?= 2026
FROM        ?= 202601
TO          ?= 202605

A_DATASETS  := A_datasets
DOWNLOAD    := ./$(A_DATASETS)/download_datasets.sh

export SAMPLE_YEAR

.PHONY: help datasets-init datasets-check datasets-download datasets-full \
        datasets-extract datasets-gbfs datasets-noaa datasets-status

help:
	@echo "4_Official_Hop_Project — Makefile"
	@echo ""
	@echo "  make datasets-check      Kiểm tra HTTP URL (không tải)"
	@echo "  make datasets-download   Trip + NOAA v2 (01–05/2026), không giải nén, không GBFS"
	@echo "  make datasets-full       Full pack: trip + NOAA + --extract + --gbfs (~2.3 GB+ disk)"
	@echo "  make datasets-extract    Trip + NOAA + giải nén ZIP"
	@echo "  make datasets-gbfs       Trip + NOAA + GBFS station_information"
	@echo "  make datasets-noaa       Chỉ NOAA LCD v2 (+ lọc 01–05)"
	@echo "  make datasets-status     manifest.json + du từng A* folder"
	@echo ""
	@echo "Biến tuỳ chọn: FROM=$(FROM) TO=$(TO) SAMPLE_YEAR=$(SAMPLE_YEAR)"
	@echo "  make datasets-download FROM=202601 TO=202601   # một tháng demo"

datasets-init:
	@chmod +x $(DOWNLOAD)

datasets-check: datasets-init
	$(DOWNLOAD) --urls-only --from $(FROM) --to $(TO)

datasets-download: datasets-init
	$(DOWNLOAD) --from $(FROM) --to $(TO)

datasets-full: datasets-init
	$(DOWNLOAD) --from $(FROM) --to $(TO) --extract --gbfs

datasets-extract: datasets-init
	$(DOWNLOAD) --from $(FROM) --to $(TO) --extract

datasets-gbfs: datasets-init
	$(DOWNLOAD) --from $(FROM) --to $(TO) --gbfs

datasets-noaa: datasets-init
	$(DOWNLOAD) --noaa-only

datasets-status:
	@echo "=== $(A_DATASETS)/manifest.json ==="
	@if [ -f $(A_DATASETS)/manifest.json ]; then cat $(A_DATASETS)/manifest.json; else echo "(chưa có — chạy make datasets-download hoặc datasets-full)"; fi
	@echo ""
	@echo "=== Dung lượng ==="
	@du -sh $(A_DATASETS)/A* 2>/dev/null || echo "(chưa có dữ liệu)"
