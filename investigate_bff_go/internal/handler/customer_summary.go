package handler

import (
	"context"
	"net/http"

	"investigate_bff/internal/domain"
)

type customerSummaryGetter interface {
	Get(ctx context.Context, cmd domain.GetCustomerSummaryCommand) (domain.CustomerSummary, error)
}

type CustomerSummaryHandler struct {
	service customerSummaryGetter
}

func NewCustomerSummaryHandler(service customerSummaryGetter) *CustomerSummaryHandler {
	return &CustomerSummaryHandler{service: service}
}

func (h *CustomerSummaryHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/investigate-bff/customer-summary", h.getCustomerSummary)
	mux.HandleFunc("GET /customer-summary", h.getCustomerSummary)
}

func (h *CustomerSummaryHandler) getCustomerSummary(w http.ResponseWriter, r *http.Request) {
	cmd, err := parseCustomerSummaryRequest(r)
	if err != nil {
		writeError(r.Context(), w, err)
		return
	}

	response, err := h.service.Get(r.Context(), cmd)
	if err != nil {
		writeError(r.Context(), w, err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}
