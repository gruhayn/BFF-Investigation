package client

import "investigate_bff/internal/model"

// Registry is the singleton client registry, initialised at startup.
// Same pattern as ms-payment-hub-ops internal/client/registry.go.
var Registry *ClientRegistry

type ClientRegistry struct {
	AddressClient     model.AddressClient
	BankAccountClient model.BankAccountClient
	TransactionClient model.TransactionClient
	ContactClient     model.ContactClient
	HolderClient      model.HolderClient
}

func InitClientRegistry() {
	Registry = &ClientRegistry{
		AddressClient:     NewAddressClient(),
		BankAccountClient: NewBankAccountClient(),
		TransactionClient: NewTransactionClient(),
		ContactClient:     NewContactClient(),
		HolderClient:      NewHolderClient(),
	}
}
