// Package main — Push GBFS station_information records to Hop MDM Web Service.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Go smoke flags: go run . -city CHI -operation INSERT -limit 5 -input A_datasets/A4_mdm_station_info/new_mdm_station_information.json

type StationStatusEnum string

const (
	MaxRetry             = 3
	MaxTimeout           = 5 * time.Second
	RetryBackoffInterval = 500 * time.Millisecond

	HopServerUsername = "cluster"
	HopServerPassword = "cluster"

	DefaultAPIKey    = "local-dev-mdm-key"
	DefaultServiceID = "mdm-station"
	DefaultAPIURL    = "http://localhost:8080/hop/webService/?service="

	StationStatusEnumOpen        StationStatusEnum = "open"
	StationStatusEnumClosed      StationStatusEnum = "closed"
	StationStatusEnumMaintenance StationStatusEnum = "maintenance"
)

type webServiceMeta struct {
	Name string `json:"name"`
}

type gbfsFeed struct {
	LastUpdated int64 `json:"last_updated"`
	Data        struct {
		Stations []gbfsStation `json:"stations"`
	} `json:"data"`
}

type gbfsStation struct {
	StationID   string  `json:"station_id"`
	Name        string  `json:"name"`
	ShortName   string  `json:"short_name"`
	Lat         float64 `json:"lat"`
	Lon         float64 `json:"lon"`
	Capacity    int     `json:"capacity"`
	StationType string  `json:"station_type"`
	RegionID    string  `json:"region_id"`
}

type mdmStationData struct {
	SourceCityCode string  `json:"source_city_code"`
	GbfsStationID  string  `json:"gbfs_station_id"`
	ShortName      string  `json:"short_name"`
	StationName    string  `json:"station_name"`
	Latitude       float64 `json:"latitude"`
	Longitude      float64 `json:"longitude"`
	Capacity       int     `json:"capacity"`
	StationType    string  `json:"station_type,omitempty"`
	RegionID       string  `json:"region_id,omitempty"`
	StationStatus  string  `json:"station_status"`
}

type mdmPushRequest struct {
	Operation string         `json:"operation"`
	SentAt    string         `json:"sent_at"`
	Data      mdmStationData `json:"data"`
}

func projectRoot() string {
	wd, err := os.Getwd()
	if err != nil {
		return "."
	}
	// C_backend/C1_mdm_station_info -> project root
	return filepath.Clean(filepath.Join(wd, "..", ".."))
}

func loadWebServiceMeta(root string) (*webServiceMeta, error) {
	path := filepath.Join(root, "metadata", "web-service", "mdm-station.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read web service metadata: %w", err)
	}
	var meta webServiceMeta
	if err := json.Unmarshal(raw, &meta); err != nil {
		return nil, fmt.Errorf("parse web service metadata: %w", err)
	}
	serviceID := envOr("HOP_MDM_STATION_SERVICE_ID", DefaultServiceID)
	if meta.Name != serviceID {
		return nil, fmt.Errorf("metadata name %q != HOP_MDM_STATION_SERVICE_ID %q", meta.Name, serviceID)
	}
	return &meta, nil
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func buildPushURL() string {
	base := envOr("HOP_MDM_API_URL", DefaultAPIURL)
	serviceID := envOr("HOP_MDM_STATION_SERVICE_ID", DefaultServiceID)
	return strings.TrimRight(base, "/") + serviceID
}

func inferCityCode(path string) string {
	lower := strings.ToLower(path)
	switch {
	case strings.Contains(lower, "divvy") || strings.Contains(lower, "chicago"):
		return "CHI"
	case strings.Contains(lower, "citibike") || strings.Contains(lower, "new_york"):
		return "NYC"
	default:
		return ""
	}
}

// inferCityCodeFromStations uses short_name / station_id prefixes (CHI… / NYC…)
// so the default new_mdm_station_information.json demo file works without -city.
func inferCityCodeFromStations(stations []gbfsStation) string {
	hasCHI, hasNYC := false, false
	for _, st := range stations {
		for _, raw := range []string{st.ShortName, st.StationID} {
			u := strings.ToUpper(strings.TrimSpace(raw))
			if strings.HasPrefix(u, "CHI") || strings.Contains(u, "CHI-") || strings.Contains(u, "-CHI-") {
				hasCHI = true
			}
			if strings.HasPrefix(u, "NYC") || strings.Contains(u, "NYC-") || strings.Contains(u, "-NYC-") {
				hasNYC = true
			}
			lower := strings.ToLower(raw)
			if strings.Contains(lower, "divvy") || strings.Contains(lower, "chicago") {
				hasCHI = true
			}
			if strings.Contains(lower, "citibike") || strings.Contains(lower, "new_york") {
				hasNYC = true
			}
		}
	}
	switch {
	case hasCHI && !hasNYC:
		return "CHI"
	case hasNYC && !hasCHI:
		return "NYC"
	default:
		return ""
	}
}

func toPushRequest(city, operation string, st gbfsStation) mdmPushRequest {
	stationStatus := string(StationStatusEnumOpen)

	short := strings.TrimSpace(st.ShortName)
	if short == "" {
		short = strings.TrimSpace(st.StationID)
	}

	return mdmPushRequest{
		Operation: operation,
		SentAt:    time.Now().UTC().Format(time.RFC3339Nano),
		Data: mdmStationData{
			SourceCityCode: city,
			GbfsStationID:  st.StationID,
			ShortName:      short,
			StationName:    st.Name,
			Latitude:       st.Lat,
			Longitude:      st.Lon,
			Capacity:       st.Capacity,
			StationType:    strings.TrimSpace(st.StationType), // "classic" or "e_bike"
			RegionID:       strings.TrimSpace(st.RegionID),
			StationStatus:  stationStatus,
		},
	}
}

func pushStation(payload mdmPushRequest) ([]byte, int, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, 0, err
	}
	
	url := buildPushURL()
	apiKey := envOr("HOP_MDM_STATION_API_KEY", DefaultAPIKey)
	var lastErr error

	for attempt := 1; attempt <= MaxRetry; attempt++ {
		req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return nil, 0, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-API-Key", apiKey)
		req.SetBasicAuth(HopServerUsername, HopServerPassword)

		client := &http.Client{Timeout: MaxTimeout}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			time.Sleep(time.Duration(attempt) * RetryBackoffInterval)
			continue
		}

		respBody, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			lastErr = readErr
			time.Sleep(time.Duration(attempt) * RetryBackoffInterval)
			continue
		}

		if resp.StatusCode >= 500 && attempt < MaxRetry {
			lastErr = fmt.Errorf("server error %d: %s", resp.StatusCode, string(respBody))
			time.Sleep(time.Duration(attempt) * RetryBackoffInterval)
			continue
		}
		return respBody, resp.StatusCode, nil
	}
	return nil, 0, fmt.Errorf("push failed after %d attempts: %w", MaxRetry, lastErr)
}

func loadStations(path string) ([]gbfsStation, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var feed gbfsFeed
	if err := json.Unmarshal(raw, &feed); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return feed.Data.Stations, nil
}

func resolveInputPath(root, flagPath string) string {
	if flagPath != "" {
		return flagPath
	}
	candidates := []string{
		filepath.Join(root, "A_datasets", "A4_mdm_station_info", "new_mdm_station_information.json"),
	}
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c
		}
	}
	return candidates[0]
}

func main() {
	operation := flag.String("operation", "INSERT", "MDM operation: INSERT|UPDATE|DELETE")
	cityFlag := flag.String("city", "", "CHI|NYC|ALL (required if not inferable from path)")
	limit := flag.Int("limit", 0, "Max stations to push (0 = all)")
	input := flag.String("input", "", "Path to station_information JSON")
	flag.Parse()

	root := projectRoot()
	if _, err := loadWebServiceMeta(root); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	path := resolveInputPath(root, *input)
	stations, err := loadStations(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	city := strings.ToUpper(strings.TrimSpace(*cityFlag))
	if city == "" || city == "ALL" {
		city = inferCityCode(path)
	}
	if city == "" || city == "ALL" {
		city = inferCityCodeFromStations(stations)
	}
	if city != "CHI" && city != "NYC" {
		fmt.Fprintf(os.Stderr, "ERROR: set -city CHI|NYC (could not infer from %s)\n", path)
		os.Exit(1)
	}

	op := strings.ToUpper(strings.TrimSpace(*operation))
	fmt.Printf("Pushing MDM stations to %s\n", buildPushURL())
	fmt.Printf("Input=%s city=%s operation=%s stations=%d limit=%d\n", path, city, op, len(stations), *limit)

	ok, fail := 0, 0
	for i, st := range stations {
		if *limit > 0 && i >= *limit {
			break
		}

		if strings.TrimSpace(st.ShortName) == "" && strings.TrimSpace(st.StationID) == "" {
			fmt.Printf("[%d] SKIP empty short_name/station_id\n", i)
			fail++
			continue
		}

		payload := toPushRequest(city, op, st)
		respBody, status, err := pushStation(payload)
		if err != nil {
			fmt.Printf("[%d] FAIL %s: %v\n", i, payload.Data.ShortName, err)
			fail++
			continue
		}
		fmt.Printf("[%d] HTTP %d short_name=%s resp=%s\n", i, status, payload.Data.ShortName, string(respBody))
		
		if status >= 200 && status < 300 {
			ok++
		} else {
			fail++
		}
	}
	
	fmt.Printf("Done: accepted_or_2xx=%d failed=%d\n", ok, fail)
	if fail > 0 && ok == 0 {
		os.Exit(1)
	}
}
