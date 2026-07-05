# 4_Official_Hop_Project — shortcuts (chạy từ thư mục này)
#   make setup-project-home   # once per machine
#   make datasets-full
#
# Windows (CMD / PowerShell): cần Git for Windows.

SAMPLE_YEAR ?= 2026
FROM        ?= 202601
TO          ?= 202605

A_DATASETS      := A_datasets
DOWNLOAD_SCRIPT := $(A_DATASETS)/download_datasets.sh
CONFIG_LOCAL    := development_configs.local.json
CONFIG_FILE     := development_configs.json
SETUP_SCRIPT    := setup_project_home.sh

# Windows: dùng Git Bash thật, không dùng bash.exe stub của WSL
ifeq ($(OS),Windows_NT)
  ifneq (,$(wildcard C:/Program Files/Git/bin/bash.exe))
    BASH := C:/Program Files/Git/bin/bash.exe
  else ifneq (,$(wildcard C:/Program Files (x86)/Git/bin/bash.exe))
    BASH := C:/Program Files (x86)/Git/bin/bash.exe
  else
    BASH := bash
  endif
else
  BASH := bash
endif

export SAMPLE_YEAR

B_DATABASES := B_databases

.PHONY: help setup-project-home datasets-check datasets-download datasets-full \
        datasets-extract datasets-gbfs datasets-noaa datasets-status \
        db-up db-down db-status

help:
	@echo "4_Official_Hop_Project — Makefile"
	@echo ""
	@echo "  make setup-project-home  Generate $(CONFIG_FILE) from $(CONFIG_LOCAL) (once per machine)"
	@echo "  make datasets-check      Kiem tra HTTP URL (khong tai)"
	@echo "  make datasets-download   Trip + NOAA v2 (01-05/2026)"
	@echo "  make datasets-full       Full pack: trip + NOAA + --extract + --gbfs + --force"
	@echo "  make datasets-extract    Trip + NOAA + giai nen ZIP"
	@echo "  make datasets-gbfs       Trip + NOAA + GBFS station_information"
	@echo "  make datasets-noaa       Chi NOAA LCD v2 (+ loc 01-05)"
	@echo "  make datasets-status     manifest.json + dung luong A*"
	@echo "  make db-up               Docker: dw_stg (5434) + dw_nds (5435) + dw_dds (5436)"
	@echo "  make db-down             Stop DW PostgreSQL containers"
	@echo "  make db-status           docker compose ps (B_databases)"
	@echo ""
	@echo "Windows (CMD/PowerShell): Git for Windows + make"
	@echo "Bien: FROM=$(FROM) TO=$(TO) SAMPLE_YEAR=$(SAMPLE_YEAR)"

define RUN_SETUP
	@chmod +x "$(SETUP_SCRIPT)" 2>/dev/null || true
	@"$(BASH)" "$(SETUP_SCRIPT)"
endef

setup-project-home:
	$(RUN_SETUP)

$(CONFIG_FILE): $(CONFIG_LOCAL) $(SETUP_SCRIPT)
	$(RUN_SETUP)

datasets-check: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --urls-only --from $(FROM) --to $(TO)

datasets-download: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --from $(FROM) --to $(TO)

datasets-full: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --from $(FROM) --to $(TO) --extract --gbfs --force

datasets-extract: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --from $(FROM) --to $(TO) --extract

datasets-gbfs: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --from $(FROM) --to $(TO) --gbfs

datasets-noaa: $(CONFIG_FILE)
	@"$(BASH)" "$(DOWNLOAD_SCRIPT)" --noaa-only

datasets-status: $(CONFIG_FILE)
	@$(BASH) -c 'test -f $(A_DATASETS)/manifest.json && cat $(A_DATASETS)/manifest.json || echo "(chua co manifest — chay make datasets-full)"'
	@echo ""
	@echo "=== Dung luong ==="
	@$(BASH) -c 'for d in $(A_DATASETS)/A*; do test -d "$$d" && du -sh "$$d" 2>/dev/null || true; done'

db-up: $(CONFIG_FILE)
	cd $(B_DATABASES) && docker-compose up -d

db-down: $(CONFIG_FILE)
	cd $(B_DATABASES) && docker-compose down -v

db-status: $(CONFIG_FILE)
	cd $(B_DATABASES) && docker-compose ps
