package api

import (
	"net/http"

	"investigate_bff/api/helper"
	"investigate_bff/internal/client"
	"investigate_bff/internal/enrichment"
	"investigate_bff/internal/mapper"
	"investigate_bff/internal/model"
)

type AccountHandler struct {
	mapper    *mapper.AccountMapper
	enrichers []model.Enricher[model.AccountDetail]
}

func NewAccountHandler(
	m *mapper.AccountMapper,
	enrichers []model.Enricher[model.AccountDetail],
) *AccountHandler {
	return &AccountHandler{mapper: m, enrichers: enrichers}
}

func (h *AccountHandler) GetAccounts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		helper.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	q := r.URL.Query()
	filter := h.mapper.ParseFilter(q)

	// Fire all client calls concurrently (omitOnError=false — accounts are required)
	accountsCh := helper.Async(func() ([]model.AccountDetail, error) {
		return client.FetchAccountDetails(filter)
	}, false)
	// Add more Async calls here when the handler needs additional client data

	// Collect results
	accountsRes := <-accountsCh
	if accountsRes.Err != nil {
		helper.RespondError(w, http.StatusInternalServerError, "failed to fetch accounts")
		return
	}
	accounts := accountsRes.Val

	offset, limit := h.mapper.ParsePagination(q)
	resp := mapper.ToPageResponse(accounts, offset, limit)

	includes := helper.ParseIncludes(q.Get("include"))
	enrichment.RunPipeline(resp.Items, h.enrichers, includes)

	helper.RespondJSON(w, resp, http.StatusOK)
}
