package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/pprof"
	"runtime"
	"time"

	"investigate_bff/api"
)

func main() {
	router := api.GetRouter()

	// pprof endpoints
	router.HandleFunc("/debug/pprof/", pprof.Index)
	router.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	router.HandleFunc("/debug/pprof/profile", pprof.Profile)
	router.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	router.HandleFunc("/debug/pprof/trace", pprof.Trace)
	router.Handle("/debug/pprof/heap", pprof.Handler("heap"))
	router.Handle("/debug/pprof/goroutine", pprof.Handler("goroutine"))
	router.Handle("/debug/pprof/allocs", pprof.Handler("allocs"))

	// runtime memory stats endpoint
	router.HandleFunc("/memstats", func(w http.ResponseWriter, _ *http.Request) {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"alloc_mb":          float64(m.Alloc) / 1024 / 1024,
			"total_alloc_mb":    float64(m.TotalAlloc) / 1024 / 1024,
			"sys_mb":            float64(m.Sys) / 1024 / 1024,
			"heap_alloc_mb":     float64(m.HeapAlloc) / 1024 / 1024,
			"heap_sys_mb":       float64(m.HeapSys) / 1024 / 1024,
			"heap_inuse_mb":     float64(m.HeapInuse) / 1024 / 1024,
			"heap_objects":      m.HeapObjects,
			"stack_inuse_mb":    float64(m.StackInuse) / 1024 / 1024,
			"stack_sys_mb":      float64(m.StackSys) / 1024 / 1024,
			"gc_cycles":         m.NumGC,
			"gc_pause_total_ms": float64(m.PauseTotalNs) / 1e6,
			"gc_pause_last_us":  float64(m.PauseNs[(m.NumGC+255)%256]) / 1e3,
			"goroutines":        runtime.NumGoroutine(),
			"num_cpu":           runtime.NumCPU(),
		})
	})

	port := "8080"
	fmt.Printf("Server running on http://localhost:%s\n", port)

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}
	log.Fatal(server.ListenAndServe())
}
