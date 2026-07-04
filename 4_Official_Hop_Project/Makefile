# 4_Official_Hop_Project — shortcuts (chạy từ thư mục này)
#   make help
#   make datasets-check
#   make datasets-full
#
# Windows: cần Git for Windows (Git Bash) — bash, curl, python, unzip trong PATH.
#   Không dùng chmod; script luôn gọi qua bash.

SAMPLE_YEAR ?= 2026
FROM        ?= 202601
TO          ?= 202605

A_DATASETS      := A_datasets
DOWNLOAD_SCRIPT := $(A_DATASETS)/download_datasets.sh

# Git Bash trên Windows; bash trên macOS/Linux
ifeq ($(OS),Windows_NT)
  BASH ?= bash
else
  BASH ?= bash
endif

RUN_DOWNLOAD = "$(BASH)" "$(DOWNLOAD_SCRIPT)"

export SAMPLE_YEAR

.PHONY: help datasets-check datasets-download datasets-full \
        datasets-extract datasets-gbfs datasets-noaa datasets-status

help:
	@echo "4_Official_Hop_Project — Makefile"
	@echo ""
	@echo "  make datasets-check      Kiem tra HTTP URL (khong tai)"
	@echo "  make datasets-download   Trip + NOAA v2 (01-05/2026)"
	@echo "  make datasets-full       Full pack: trip + NOAA + --extract + --gbfs"
	@echo "  make datasets-extract    Trip + NOAA + giai nen ZIP"
	@echo "  make datasets-gbfs       Trip + NOAA + GBFS station_information"
	@echo "  make datasets-noaa       Chi NOAA LCD v2 (+ loc 01-05)"
	@echo "  make datasets-status     manifest.json + dung luong A*"
	@echo ""
	@echo "Windows: Git Bash + curl + python + unzip (Git for Windows)"
	@echo "Biến: FROM=$(FROM) TO=$(TO) SAMPLE_YEAR=$(SAMPLE_YEAR)"

datasets-check:
	$(RUN_DOWNLOAD) --urls-only --from $(FROM) --to $(TO)

datasets-download:
	$(RUN_DOWNLOAD) --from $(FROM) --to $(TO)

datasets-full:
	$(RUN_DOWNLOAD) --from $(FROM) --to $(TO) --extract --gbfs

datasets-extract:
	$(RUN_DOWNLOAD) --from $(FROM) --to $(TO) --extract

datasets-gbfs:
	$(RUN_DOWNLOAD) --from $(FROM) --to $(TO) --gbfs

datasets-noaa:
	$(RUN_DOWNLOAD) --noaa-only

datasets-status:
	@$(BASH) -c 'test -f $(A_DATASETS)/manifest.json && cat $(A_DATASETS)/manifest.json || echo "(chua co manifest — chay make datasets-full)"'
	@echo ""
	@echo "=== Dung luong ==="
	@$(BASH) -c 'for d in $(A_DATASETS)/A*; do test -d "$$d" && du -sh "$$d" 2>/dev/null || true; done'
