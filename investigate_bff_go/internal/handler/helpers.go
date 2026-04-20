package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"investigate_bff/internal/domain"
	"investigate_bff/internal/logger"
)

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
	}
}

func writeBadRequest(ctx context.Context, w http.ResponseWriter, message string) {
	requestID := requestIDFromContext(ctx)
	log := logger.FromCtx(ctx)
	log.Warn("malformed request", "operation", "HTTP", "event", "Failed", "status", http.StatusBadRequest)
	writeJSON(w, http.StatusBadRequest, errorResponse{
		Error: errorBody{
			Code:    "INVESTIGATE_BFF.BAD_REQUEST.BAD_REQUEST",
			Message: message,
			ID:      requestID,
		},
	})
}

func writeValidationError(ctx context.Context, w http.ResponseWriter, err error) {
	requestID := requestIDFromContext(ctx)
	log := logger.FromCtx(ctx)
	validationErr, _ := domain.AsValidationError(err)

	details := make([]errorDetail, 0, len(validationErr.Details))
	for _, detail := range validationErr.Details {
		details = append(details, errorDetail{
			Field:  detail.Field,
			Reason: detail.Reason,
			Meta:   detail.Meta,
		})
	}

	log.Warn("validation failed", "operation", "HTTP", "event", "ValidationFailed", "errorCode", "INVESTIGATE_BFF.VALIDATION.VALIDATION_FAILED", "status", http.StatusUnprocessableEntity)
	writeJSON(w, http.StatusUnprocessableEntity, errorResponse{
		Error: errorBody{
			Code:    "INVESTIGATE_BFF.VALIDATION.VALIDATION_FAILED",
			Message: "Request validation failed.",
			ID:      requestID,
			Details: details,
		},
	})
}

func writeDomainError(ctx context.Context, w http.ResponseWriter, err error) {
	status, code, message := mapErrorInfo(err)
	requestID := requestIDFromContext(ctx)
	log := logger.FromCtx(ctx)
	logFn := log.Error
	if status < http.StatusInternalServerError {
		logFn = log.Warn
	}
	logFn("request failed", "operation", "HTTP", "event", "Failed", "errorCode", code, "errorId", requestID, "status", status)

	writeJSON(w, status, errorResponse{
		Error: errorBody{
			Code:    code,
			Message: message,
			ID:      requestID,
		},
	})
}

func writeInternalError(ctx context.Context, w http.ResponseWriter, err error) {
	requestID := requestIDFromContext(ctx)
	log := logger.FromCtx(ctx)
	log.Error("unexpected failure", "operation", "HTTP", "event", "Failed", "errorCode", "INVESTIGATE_BFF.SERVER.INTERNAL_ERROR", "errorId", requestID, "status", http.StatusInternalServerError, "error", err)
	writeJSON(w, http.StatusInternalServerError, errorResponse{
		Error: errorBody{
			Code:    "INVESTIGATE_BFF.SERVER.INTERNAL_ERROR",
			Message: "Internal server error.",
			ID:      requestID,
		},
	})
}

func writeError(ctx context.Context, w http.ResponseWriter, err error) {
	var malformed *badRequestError
	switch {
	case errors.As(err, &malformed):
		writeBadRequest(ctx, w, malformed.Error())
	case isValidationError(err):
		writeValidationError(ctx, w, err)
	default:
		writeDomainError(ctx, w, err)
	}
}

func isValidationError(err error) bool {
	_, ok := domain.AsValidationError(err)
	return ok
}
