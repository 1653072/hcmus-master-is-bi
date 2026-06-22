package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	MaxRetry             = 3
	MaxTimeout           = 6 * time.Second
	HopETLDomain         = "http://127.0.0.1:8080"
	HopMDMUsersAPIKey    = "local-dev-mdm-key"
	HopMDMUsersServiceID = "mdm-users"
	// Hop Server HTTP Basic Auth (default Apache Hop install; separate from X-API-Key).
	HopServerUsername = "cluster"
	HopServerPassword = "cluster"
)

type webServiceMeta struct {
	Name string `json:"name"`
}

type mdmUserData struct {
	UserID              int     `json:"user_id"`
	Username            string  `json:"username"`
	Email               string  `json:"email"`
	Age                 int     `json:"age"`
	Gender              string  `json:"gender"`
	Occupation          *string `json:"occupation,omitempty"`
	CreatedAt           string  `json:"created_at"`
	LastUpdateTimestamp string  `json:"last_update_timestamp"`
}

type mdmPushRequest struct {
	Operation string      `json:"operation"`
	SentAt    string      `json:"sent_at"`
	Data      mdmUserData `json:"data"`
}

func loadWebServiceMeta() (*webServiceMeta, error) {
	path := filepath.Join("..", "metadata", "web-service", "mdm-users.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read web service metadata: %w", err)
	}
	var meta webServiceMeta
	if err := json.Unmarshal(raw, &meta); err != nil {
		return nil, fmt.Errorf("parse web service metadata: %w", err)
	}
	if meta.Name != HopMDMUsersServiceID {
		return nil, fmt.Errorf("metadata name %q != HopMDMUsersServiceID %q", meta.Name, HopMDMUsersServiceID)
	}
	return &meta, nil
}

func buildPushURL() string {
	return fmt.Sprintf("%s/hop/webService/?service=%s", strings.TrimRight(HopETLDomain, "/"), HopMDMUsersServiceID)
}

func randomDemoUser() mdmPushRequest {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	userID := 90000 + rand.Intn(9999)
	occupation := randomOccupation()
	return mdmPushRequest{
		Operation: "INSERT",
		SentAt:    now,
		Data: mdmUserData{
			UserID:              userID,
			Username:            fmt.Sprintf("demo_user_%d", userID),
			Email:               fmt.Sprintf("demo_user_%d@movielens.local", userID),
			Age:                 18 + rand.Intn(50),
			Gender:              randomGender(),
			Occupation:          &occupation,
			CreatedAt:           now,
			LastUpdateTimestamp: now,
		},
	}
}

func randomGender() string {
	if rand.Intn(2) == 0 {
		return "M"
	}
	return "F"
}

func randomOccupation() string {
	occupations := []string{"student", "engineer", "artist", "teacher", "doctor", "analyst"}
	return occupations[rand.Intn(len(occupations))]
}

func pushMDMUser(payload mdmPushRequest) ([]byte, int, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, 0, err
	}

	url := buildPushURL()
	var lastErr error

	for attempt := 1; attempt <= MaxRetry; attempt++ {
		req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return nil, 0, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-API-Key", HopMDMUsersAPIKey)
		req.SetBasicAuth(HopServerUsername, HopServerPassword)

		client := &http.Client{Timeout: MaxTimeout}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			time.Sleep(time.Duration(attempt) * 500 * time.Millisecond)
			continue
		}

		respBody, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			lastErr = readErr
			time.Sleep(time.Duration(attempt) * 500 * time.Millisecond)
			continue
		}

		if resp.StatusCode >= 500 && attempt < MaxRetry {
			lastErr = fmt.Errorf("server error %d: %s", resp.StatusCode, string(respBody))
			time.Sleep(time.Duration(attempt) * 500 * time.Millisecond)
			continue
		}

		return respBody, resp.StatusCode, nil
	}

	return nil, 0, fmt.Errorf("push failed after %d attempts: %w", MaxRetry, lastErr)
}

func RunPushMDMUserDemo() error {
	if _, err := loadWebServiceMeta(); err != nil {
		return err
	}

	payload := randomDemoUser()
	fmt.Printf("Pushing MDM user to %s\n", buildPushURL())
	fmt.Printf("Payload: user_id=%d operation=%s\n", payload.Data.UserID, payload.Operation)

	respBody, status, err := pushMDMUser(payload)
	if err != nil {
		return err
	}

	fmt.Printf("HTTP %d\n", status)
	fmt.Printf("Response: %s\n", string(respBody))

	if status < 200 || status >= 300 {
		return fmt.Errorf("unexpected status %d", status)
	}
	return nil
}
