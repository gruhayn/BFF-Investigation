package logger

import (
	"context"
	"log/slog"
)

type contextKey struct{}

func ToCtx(ctx context.Context, log *slog.Logger) context.Context {
	return context.WithValue(ctx, contextKey{}, log)
}

func FromCtx(ctx context.Context) *slog.Logger {
	if log, ok := ctx.Value(contextKey{}).(*slog.Logger); ok && log != nil {
		return log
	}
	return slog.Default()
}
