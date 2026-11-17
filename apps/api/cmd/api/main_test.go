package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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

func TestOpenAPIStable(t *testing.T) {
	_, firstAPI := newAPI()
	first, err := firstAPI.OpenAPI().YAML()
	if err != nil {
		t.Fatalf("first YAML: %v", err)
	}

	_, secondAPI := newAPI()
	second, err := secondAPI.OpenAPI().YAML()
	if err != nil {
		t.Fatalf("second YAML: %v", err)
	}

	if !bytes.Equal(first, second) {
		t.Fatal("openapi YAML differs between two runs")
	}
	if !bytes.Contains(first, []byte("/healthz")) {
		t.Fatal("openapi YAML does not contain /healthz")
	}
}

func TestRunOpenAPIWritesFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nested", "openapi.yaml")

	if err := runOpenAPI([]string{"--output", path}); err != nil {
		t.Fatalf("first runOpenAPI: %v", err)
	}
	first, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read first output: %v", err)
	}
	if len(first) == 0 {
		t.Fatal("first output is empty")
	}

	if err := runOpenAPI([]string{"--output", path}); err != nil {
		t.Fatalf("second runOpenAPI: %v", err)
	}
	second, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read second output: %v", err)
	}
	if !bytes.Equal(first, second) {
		t.Fatal("openapi output differs between two runs")
	}

	tempFiles, err := filepath.Glob(filepath.Join(dir, "nested", ".openapi-*"))
	if err != nil {
		t.Fatalf("glob temp files: %v", err)
	}
	if len(tempFiles) != 0 {
		t.Fatalf("leftover temp files: %v", tempFiles)
	}
}

func TestRunOpenAPIRejectsStdout(t *testing.T) {
	if err := runOpenAPI([]string{"--output", "-"}); err == nil {
		t.Fatal("runOpenAPI accepted stdout output")
	}
}

func TestRunRejectsUnknownSubcommand(t *testing.T) {
	if err := run([]string{"unknown"}); err == nil {
		t.Fatal("run accepted unknown subcommand")
	}
}
