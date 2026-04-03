package api

import (
	"net/http"

	"investigate_bff/api/helper"
	"investigate_bff/internal/client"
	"investigate_bff/internal/mapper"
	"investigate_bff/internal/model"
)

type CustomerSummaryHandler struct {
	mapper *mapper.CustomerSummaryMapper
}

func NewCustomerSummaryHandler(m *mapper.CustomerSummaryMapper) *CustomerSummaryHandler {
	return &CustomerSummaryHandler{mapper: m}
}

func (h *CustomerSummaryHandler) GetCustomerSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		helper.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	customerID := r.URL.Query().Get("id")
	if customerID == "" {
		helper.RespondError(w, http.StatusBadRequest, "id query parameter is required")
		return
	}

	ids := []string{customerID}

	// Fire 4 client calls concurrently via goroutines
	customersCh := helper.Async(func() ([]model.Customer, error) {
		return client.FetchCustomers(model.CustomerFilter{ID: customerID})
	}, false)
	addressesCh := helper.Async(func() (map[string][]model.Address, error) {
		return client.Registry.AddressClient.GetByCustomerIDs(ids)
	}, true)
	accountsCh := helper.Async(func() (map[string][]model.BankAccount, error) {
		return client.Registry.BankAccountClient.GetByCustomerIDs(ids)
	}, true)
	contactsCh := helper.Async(func() (map[string][]model.Contact, error) {
		return client.Registry.ContactClient.GetByCustomerIDs(ids)
	}, true)

	// Collect results
	customersRes := <-customersCh
	if customersRes.Err != nil {
		helper.RespondError(w, http.StatusInternalServerError, "failed to fetch customer")
		return
	}
	customers := customersRes.Val
	addressMap := (<-addressesCh).Val
	accountMap := (<-accountsCh).Val
	contactMap := (<-contactsCh).Val

	if len(customers) == 0 {
		helper.RespondError(w, http.StatusNotFound, "customer not found")
		return
	}
	cust := customers[0]
	accounts := accountMap[customerID]

	// Second wave: fetch transactions for all accounts
	accountIDs := make([]string, len(accounts))
	for i, a := range accounts {
		accountIDs[i] = a.ID
	}
	txnMap, _ := client.Registry.TransactionClient.GetByAccountIDs(accountIDs)

	summary := h.mapper.MapSummary(cust, addressMap[customerID], accounts, txnMap, contactMap[customerID])

	helper.RespondJSON(w, summary, http.StatusOK)
}
