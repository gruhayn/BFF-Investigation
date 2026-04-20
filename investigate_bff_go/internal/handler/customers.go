package handler

import (
	"context"
	"net/http"

	"investigate_bff/internal/domain"
)

type customerLister interface {
	List(ctx context.Context, cmd domain.ListCustomersCommand) (domain.PageResult[domain.Customer], error)
}

type CustomerHandler struct {
	service customerLister
}

func NewCustomerHandler(service customerLister) *CustomerHandler {
	return &CustomerHandler{service: service}
}

func (h *CustomerHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/investigate-bff/customers", h.listCustomers)
	mux.HandleFunc("GET /customers", h.listCustomers)
}

func (h *CustomerHandler) listCustomers(w http.ResponseWriter, r *http.Request) {
	cmd, err := parseListCustomersRequest(r)
	if err != nil {
		writeError(r.Context(), w, err)
		return
	}

	response, err := h.service.List(r.Context(), cmd)
	if err != nil {
		writeError(r.Context(), w, err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}
