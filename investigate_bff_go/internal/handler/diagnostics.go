package handler

import (
	"net/http"
	"net/http/pprof"
	"runtime"
)

type DiagnosticsHandler struct{}

func NewDiagnosticsHandler() *DiagnosticsHandler {
	return &DiagnosticsHandler{}
}

func (h *DiagnosticsHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("GET /api/v1/investigate-bff/health", health)
	mux.HandleFunc("GET /memstats", memstats)
	mux.HandleFunc("GET /debug/pprof/", pprof.Index)
	mux.HandleFunc("GET /debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("GET /debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("GET /debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("GET /debug/pprof/trace", pprof.Trace)
	mux.Handle("GET /debug/pprof/heap", pprof.Handler("heap"))
	mux.Handle("GET /debug/pprof/goroutine", pprof.Handler("goroutine"))
	mux.Handle("GET /debug/pprof/allocs", pprof.Handler("allocs"))
}

func health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func memstats(w http.ResponseWriter, _ *http.Request) {
	var memoryStats runtime.MemStats
	runtime.ReadMemStats(&memoryStats)

	writeJSON(w, http.StatusOK, map[string]any{
		"alloc_mb":          float64(memoryStats.Alloc) / 1024 / 1024,
		"total_alloc_mb":    float64(memoryStats.TotalAlloc) / 1024 / 1024,
		"sys_mb":            float64(memoryStats.Sys) / 1024 / 1024,
		"heap_alloc_mb":     float64(memoryStats.HeapAlloc) / 1024 / 1024,
		"heap_sys_mb":       float64(memoryStats.HeapSys) / 1024 / 1024,
		"heap_inuse_mb":     float64(memoryStats.HeapInuse) / 1024 / 1024,
		"heap_objects":      memoryStats.HeapObjects,
		"stack_inuse_mb":    float64(memoryStats.StackInuse) / 1024 / 1024,
		"stack_sys_mb":      float64(memoryStats.StackSys) / 1024 / 1024,
		"gc_cycles":         memoryStats.NumGC,
		"gc_pause_total_ms": float64(memoryStats.PauseTotalNs) / 1e6,
		"gc_pause_last_us":  float64(memoryStats.PauseNs[(memoryStats.NumGC+255)%256]) / 1e3,
		"goroutines":        runtime.NumGoroutine(),
		"num_cpu":           runtime.NumCPU(),
	})
}
