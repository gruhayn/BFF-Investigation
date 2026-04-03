package helper

import (
	"encoding/json"
	"net/http"
	"strings"
)

func RespondJSON(w http.ResponseWriter, data any, status int) {
	b, err := json.Marshal(data)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(b)
}

func RespondError(w http.ResponseWriter, status int, msg string) {
	b, _ := json.Marshal(map[string]string{"error": msg})
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(b)
}

func ParseIncludes(s string) map[string]bool {
	m := make(map[string]bool)
	for _, v := range strings.Split(s, ",") {
		v = strings.TrimSpace(v)
		if v != "" {
			m[v] = true
		}
	}
	return m
}

// Result holds the value and error from an async client call.
type Result[T any] struct {
	Val T
	Err error
}

// Async runs fn in a goroutine and returns a channel with the Result.
// If omitOnError is true, errors are logged and swallowed — Val will be the zero value, Err will be nil.
// If omitOnError is false, the error is passed through for the caller to handle.
func Async[T any](fn func() (T, error), omitOnError bool) <-chan Result[T] {
	ch := make(chan Result[T], 1)
	go func() {
		v, err := fn()
		if err != nil && omitOnError {
			var zero T
			ch <- Result[T]{Val: zero}
		} else {
			ch <- Result[T]{Val: v, Err: err}
		}
	}()
	return ch
}
