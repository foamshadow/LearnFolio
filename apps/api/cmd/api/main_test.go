package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthz(t *testing.T) {
	mux, _ := newAPI()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["status"] != "ok" {
		t.Fatalf("status body = %q, want %q", body["status"], "ok")
	}
	if _, ok := body["$schema"]; ok {
		t.Fatal("unexpected $schema field in health response")
	}
}

func TestListenPort(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		want    int
		wantErr bool
	}{
		{name: "default", value: "", want: defaultPort},
		{name: "override", value: "18080", want: 18080},
		{name: "not a number", value: "abc", wantErr: true},
		{name: "zero", value: "0", wantErr: true},
		{name: "too large", value: "65536", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("PORT", tt.value)

			got, err := listenPort()
			if (err != nil) != tt.wantErr {
				t.Fatalf("listenPort() error = %v, wantErr %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Fatalf("listenPort() = %d, want %d", got, tt.want)
			}
		})
	}
}
