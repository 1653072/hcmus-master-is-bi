# KPI Report — Jan–May 2026

Source: `dds.fact_station_hour_balance` (+ dims) via `sql/kpi_report_actuals_2026_jan_may.sql`.

- **Plan** = Target (constant repeated for YTD and each month).
- **Actual** = queried from `dw_dds`.
- **YTD** = same formula recomputed over Jan–May 2026 (not the average of monthly Actuals).

Thresholds: serious imbalance `abs_imbalance >= 4`; prolonged depletion `> 6` hours with `net_flow < 0` per station-day; peak hours = weekdays 07:00–08:00 and 17:00–18:00 (`dim_datetime.is_peak_hour`).

Values independently re-verified against DDS (formulas A–K match raw aggregates).

## KPI Vận hành

### A. Mức mất cân bằng xe trung bình mỗi trạm/giờ (AVG abs_imbalance)

**Target:** 4.0

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 4.0 | 4.0 | 4.0 | 4.0 | 4.0 | 4.0 |
| **Actual** | 1.9 | 1.7 | 1.5 | 1.9 | 2.1 | 2.2 |

### B. Tỷ lệ station-hour mất cân bằng nghiêm trọng (abs_imbalance ≥ 4)

**Target:** 10.0%

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 10.0% | 10.0% | 10.0% | 10.0% | 10.0% | 10.0% |
| **Actual** | 12.6% | 9.8% | 7.8% | 12.2% | 14.5% | 15.6% |

### C. Số lần trạm–ngày rút cạn kéo dài hơn 6 tiếng (net_flow < 0)

**Target:** 5

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 5 | 5 | 5 | 5 | 5 | 5 |
| **Actual** | 152009 | 21910 | 17473 | 31734 | 36713 | 44179 |

### D. Mức mất cân bằng giờ cao điểm (07:00–08:00 và 17:00–18:00 vào ngày thường) so với giờ thường

**Target:** 1.50

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 1.50 | 1.50 | 1.50 | 1.50 | 1.50 | 1.50 |
| **Actual** | 1.6 | 1.6 | 1.4 | 1.6 | 1.7 | 1.7 |

### E. Chênh lệch mất cân bằng trung bình giữa Chicago và New York (|AVG_CHI − AVG_NYC|)

**Target:** 1.0

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| **Actual** | 0.6 | 0.6 | 0.3 | 0.6 | 0.7 | 0.7 |

### F. Chênh lệch mất cân bằng khi trời mưa so với trời quang (AVG_Rain − AVG_Clear)

**Target:** —

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | — | — | — | — | — | — |
| **Actual** | -0.2 | -0.1 | -0.3 | -0.2 | -0.4 | -0.3 |

## KPI - Nhu cầu & Hành vi người dùng

### G. Số chuyến đi bắt đầu trung bình mỗi trạm/giờ (AVG trips_started)

**Target:** 3.0

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 3.0 | 3.0 | 3.0 | 3.0 | 3.0 | 3.0 |
| **Actual** | 3.0 | 2.2 | 1.9 | 2.8 | 3.4 | 3.8 |

### H. Tỷ lệ chuyến đi Member/Casual (SUM member ÷ SUM casual)

**Target:** 2.00

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 2.00 | 2.00 | 2.00 | 2.00 | 2.00 | 2.00 |
| **Actual** | 5.20 | 9.56 | 8.70 | 5.70 | 4.86 | 3.97 |

### I. Tỷ lệ sử dụng xe điện trên tổng chuyến classic + electric

**Target:** 30%

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 30% | 30% | 30% | 30% | 30% | 30% |
| **Actual** | 71.2% | 71.8% | 71.2% | 71.0% | 71.4% | 71.0% |

### J. Mức sụt giảm nhu cầu khi mưa/tuyết so với trời quang (% giảm AVG trips_started)

**Target:** 15%

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | 15% | 15% | 15% | 15% | 15% | 15% |
| **Actual** | 34.3% | 30.8% | 41.1% | 31.1% | 35.9% | 29.0% |

### K. Tổng số chuyến đi bắt đầu theo thành phố (CHI / NYC)

**Target:** —

|  | YTD | Jan | Feb | Mar | Apr | May |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Plan** | — | — | — | — | — | — |
| **Actual** | CHI: 1375679 / NYC: 14205943 | CHI: 109943 / NYC: 1771331 | CHI: 165705 / NYC: 1192497 | CHI: 253279 / NYC: 2861376 | CHI: 348349 / NYC: 3759640 | CHI: 498403 / NYC: 4621099 |
