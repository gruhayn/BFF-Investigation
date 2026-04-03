package api

import (
	"net/http"

	"investigate_bff/internal/client"
	"investigate_bff/internal/enrichment"
	"investigate_bff/internal/mapper"
)

func GetRouter() *http.ServeMux {
	client.InitClientRegistry()

	customerHandler := NewCustomerHandler(
		mapper.NewCustomerMapper(),
		enrichment.NewCustomerEnrichers(),
	)

	accountHandler := NewAccountHandler(
		mapper.NewAccountMapper(),
		enrichment.NewAccountDetailEnrichers(),
	)

	summaryHandler := NewCustomerSummaryHandler(
		mapper.NewCustomerSummaryMapper(),
	)

	mux := http.NewServeMux()
	mux.HandleFunc("/customers", customerHandler.GetCustomers)
	mux.HandleFunc("/accounts", accountHandler.GetAccounts)
	mux.HandleFunc("/customer-summary", summaryHandler.GetCustomerSummary)
	mux.HandleFunc("/health", health)

	return mux
}

func health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}
