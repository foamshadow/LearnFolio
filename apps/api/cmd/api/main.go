package main

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"
	"github.com/foamshadow/learnfolio/internal/handler"
)

const (
	defaultPort = 8080
	apiVersion  = "0.1.0"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
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
