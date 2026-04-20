package handler

import (
	"context"
	"net/http"

	"investigate_bff/internal/domain"
)

type accountLister interface {
	List(ctx context.Context, cmd domain.ListAccountsCommand) (domain.PageResult[domain.AccountDetail], error)
}

type AccountHandler struct {
	service accountLister
}

func NewAccountHandler(service accountLister) *AccountHandler {
	return &AccountHandler{service: service}
}

func (h *AccountHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/investigate-bff/accounts", h.listAccounts)
	mux.HandleFunc("GET /accounts", h.listAccounts)
}

func (h *AccountHandler) listAccounts(w http.ResponseWriter, r *http.Request) {
	cmd, err := parseListAccountsRequest(r)
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
