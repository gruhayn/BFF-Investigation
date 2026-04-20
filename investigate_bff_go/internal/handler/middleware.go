package handler

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"runtime/debug"
	"sync/atomic"
	"time"

	"investigate_bff/internal/logger"
)

type requestIDKey struct{}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

var requestCounter uint64

func (w *statusRecorder) WriteHeader(status int) {
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}

func Recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				log := logger.FromCtx(r.Context())
				log.Error("panic recovered", "operation", "HTTP", "event", "Failed", "status", http.StatusInternalServerError, "panic", recovered, "stack", string(debug.Stack()))
				writeInternalError(r.Context(), w, fmt.Errorf("panic: %v", recovered))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func RequestContext(baseLogger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			requestID := newRequestID()
			requestLogger := baseLogger.With("requestId", requestID)
			ctx := context.WithValue(r.Context(), requestIDKey{}, requestID)
			ctx = logger.ToCtx(ctx, requestLogger)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		log := logger.FromCtx(r.Context())

		log.Info("request started", "operation", "HTTP", "event", "Start", "method", r.Method, "path", r.URL.Path)
		next.ServeHTTP(recorder, r)

		event := "Success"
		logFn := log.Info
		if recorder.status >= http.StatusBadRequest {
			event = "Failed"
			logFn = log.Warn
		}

		logFn("request completed",
			"operation", "HTTP",
			"event", event,
			"method", r.Method,
			"path", r.URL.Path,
			"status", recorder.status,
			"durationMs", time.Since(start).Milliseconds(),
		)
	})
}

func requestIDFromContext(ctx context.Context) string {
	if requestID, ok := ctx.Value(requestIDKey{}).(string); ok {
		return requestID
	}
	return ""
}

func newRequestID() string {
	return fmt.Sprintf("req-%d", atomic.AddUint64(&requestCounter, 1))
}
