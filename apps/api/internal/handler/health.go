package handler

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
)

// HealthBody 是 /healthz 的响应体。liveness 只表示进程可服务，
// 不检查数据库或其它外部依赖；readiness 等有依赖后再单独加。
type HealthBody struct {
	Status string `json:"status" example:"ok" doc:"服务存活状态"`
}

// HealthOutput 遵循 huma 的输出约定：响应体放在 Body 字段。
type HealthOutput struct {
	Body HealthBody
}

// RegisterHealth 只注册路由，不依赖 DB 或全局状态，供 server 与
// openapi 子命令共用；调用方负责构造 huma.API。
func RegisterHealth(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "get-healthz",
		Method:      http.MethodGet,
		Path:        "/healthz",
		Summary:     "Liveness probe",
		Tags:        []string{"system"},
	}, func(_ context.Context, _ *struct{}) (*HealthOutput, error) {
		return &HealthOutput{Body: HealthBody{Status: "ok"}}, nil
	})
}
