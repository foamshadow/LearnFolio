package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"
	"github.com/foamshadow/learnfolio/internal/handler"
)

const (
	defaultPort        = 8080
	apiVersion         = "0.1.0"
	defaultOpenAPIPath = "docs/openapi.yaml"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return runServer()
	}

	switch args[0] {
	case "openapi":
		return runOpenAPI(args[1:])
	default:
		return fmt.Errorf("unknown subcommand %q (expected: openapi)", args[0])
	}
}

func runServer() error {
	port, err := listenPort()
	if err != nil {
		return err
	}

	mux, _ := newAPI()
	srv := &http.Server{
		Addr:              ":" + strconv.Itoa(port),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("listening on %s", srv.Addr)

	err = srv.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

// runOpenAPI 复用 server 的 newAPI()，只导出契约、不监听端口。
// 子命令自带写盘，避免 shell 重定向参与编码（PowerShell 的 > 会重编 UTF-16）。
func runOpenAPI(args []string) error {
	fs := flag.NewFlagSet("openapi", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	output := fs.String("output", defaultOpenAPIPath, "output file path (must not be -)")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 0 {
		return fmt.Errorf("openapi: unexpected arguments: %v", fs.Args())
	}
	if *output == "" || *output == "-" {
		return fmt.Errorf("openapi: --output must be a file path, not stdout")
	}

	_, api := newAPI()
	data, err := api.OpenAPI().YAML()
	if err != nil {
		return fmt.Errorf("generate openapi: %w", err)
	}
	if err := writeFileAtomic(*output, data, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", *output, err)
	}
	return nil
}

// newAPI 构造 server 与 openapi 子命令共用的路由。
// 路由注册必须留在这个函数内，且不能依赖 DB 连接：生成契约时不会起服务。
func newAPI() (http.Handler, huma.API) {
	mux := http.NewServeMux()
	api := humago.New(mux, newAPIConfig())
	handler.RegisterHealth(api)
	return mux, api
}

// newAPIConfig 关闭 Huma 默认的 $schema / Link 注入：它会让响应体带上
// 随请求 Host 变化的 schema URL，而本项目的契约真源是 openapi.yaml。
// health 只返回业务字段，客户端不需要运行期 schema 发现。
func newAPIConfig() huma.Config {
	config := huma.DefaultConfig("LearnFolio API", apiVersion)
	config.CreateHooks = nil
	config.Transformers = nil
	config.SchemasPath = ""
	return config
}

func listenPort() (int, error) {
	raw := os.Getenv("PORT")
	if raw == "" {
		return defaultPort, nil
	}

	port, err := strconv.Atoi(raw)
	if err != nil || port < 1 || port > 65535 {
		return 0, fmt.Errorf("invalid PORT %q: must be an integer between 1 and 65535", raw)
	}
	return port, nil
}

// writeFileAtomic 在同目录写临时文件，成功后再 rename 覆盖目标。
// 先落临时文件可避免进程中断留下半截 openapi.yaml；rename 保证读者
// 只会看到旧文件或完整新文件。
func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	f, err := os.CreateTemp(dir, ".openapi-*.yaml")
	if err != nil {
		return err
	}
	tmp := f.Name()
	renamed := false
	defer func() {
		if !renamed {
			_ = os.Remove(tmp)
		}
	}()

	if _, err := f.Write(data); err != nil {
		_ = f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	if err := os.Chmod(tmp, perm); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		return err
	}
	renamed = true
	return nil
}
