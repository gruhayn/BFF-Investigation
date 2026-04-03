package api

import (
	"net/http"

	"investigate_bff/api/helper"
	"investigate_bff/internal/client"
	"investigate_bff/internal/enrichment"
	"investigate_bff/internal/mapper"
	"investigate_bff/internal/model"
)

type CustomerHandler struct {
	mapper    *mapper.CustomerMapper
	enrichers []model.Enricher[model.Customer]
}

func NewCustomerHandler(
	m *mapper.CustomerMapper,
	enrichers []model.Enricher[model.Customer],
) *CustomerHandler {
	return &CustomerHandler{mapper: m, enrichers: enrichers}
}

func (h *CustomerHandler) GetCustomers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		helper.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	q := r.URL.Query()
	filter := h.mapper.ParseFilter(q)

	// Fire all client calls concurrently (omitOnError=false — customers are required)
	customersCh := helper.Async(func() ([]model.Customer, error) {
		return client.FetchCustomers(filter)
	}, false)
	// Add more Async calls here when the handler needs additional client data

	// Collect results
	customersRes := <-customersCh
	if customersRes.Err != nil {
		helper.RespondError(w, http.StatusInternalServerError, "failed to fetch customers")
		return
	}
	customers := customersRes.Val

	offset, limit := h.mapper.ParsePagination(q)
	resp := mapper.ToPageResponse(customers, offset, limit)

	includes := helper.ParseIncludes(q.Get("include"))
	enrichment.RunPipeline(resp.Items, h.enrichers, includes)

	helper.RespondJSON(w, resp, http.StatusOK)
}
