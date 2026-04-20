package app

import (
	"fmt"
	"log/slog"
	"net/http"

	"investigate_bff/config"
	"investigate_bff/internal/handler"
	"investigate_bff/internal/infra/client"
	"investigate_bff/internal/service"
)

func Run(cfg *config.Config, baseLogger *slog.Logger) error {
	registry := client.NewRegistry()

	customersService := service.NewCustomersService(
		registry.Customers,
		registry.Addresses,
		registry.Accounts,
		registry.Transactions,
		registry.Contacts,
	)
	accountsService := service.NewAccountsService(
		registry.Accounts,
		registry.Holders,
		registry.Transactions,
	)
	customerSummaryService := service.NewCustomerSummaryService(
		registry.Customers,
		registry.Addresses,
		registry.Accounts,
		registry.Transactions,
		registry.Contacts,
	)

	customersHandler := handler.NewCustomerHandler(customersService)
	accountsHandler := handler.NewAccountHandler(accountsService)
	customerSummaryHandler := handler.NewCustomerSummaryHandler(customerSummaryService)
	diagnosticsHandler := handler.NewDiagnosticsHandler()

	mux := http.NewServeMux()
	customersHandler.RegisterRoutes(mux)
	accountsHandler.RegisterRoutes(mux)
	customerSummaryHandler.RegisterRoutes(mux)
	diagnosticsHandler.RegisterRoutes(mux)

	httpHandler := handler.Recoverer(handler.RequestContext(baseLogger)(handler.Logging(mux)))
	server := &http.Server{
		Addr:         ":" + cfg.ServerPort,
		Handler:      httpHandler,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}

	slog.Info("starting server", "address", fmt.Sprintf("http://localhost:%s", cfg.ServerPort))
	return server.ListenAndServe()
}
