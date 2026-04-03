package enrichment

import (
	"investigate_bff/internal/client"
	"investigate_bff/internal/model"
)

func NewCustomerEnrichers() []model.Enricher[model.Customer] {
	return []model.Enricher[model.Customer]{
		&addressEnricher{client: client.Registry.AddressClient},
		&bankAccountEnricher{client: client.Registry.BankAccountClient},
		&transactionEnricher{client: client.Registry.TransactionClient},
		&contactEnricher{client: client.Registry.ContactClient},
	}
}

type addressEnricher struct{ client model.AddressClient }

func (e *addressEnricher) Key() string       { return "addresses" }
func (e *addressEnricher) DependsOn() string { return "" }

func (e *addressEnricher) Enrich(customers []model.Customer) {
	ids := make([]string, len(customers))
	for i := range customers {
		ids[i] = customers[i].ID
	}
	grouped, err := e.client.GetByCustomerIDs(ids)
	if err != nil {
		return
	}
	for i := range customers {
		customers[i].Addresses = grouped[customers[i].ID]
	}
}

type bankAccountEnricher struct{ client model.BankAccountClient }

func (e *bankAccountEnricher) Key() string       { return "bankAccounts" }
func (e *bankAccountEnricher) DependsOn() string { return "" }

func (e *bankAccountEnricher) Enrich(customers []model.Customer) {
	ids := make([]string, len(customers))
	for i := range customers {
		ids[i] = customers[i].ID
	}
	grouped, err := e.client.GetByCustomerIDs(ids)
	if err != nil {
		return
	}
	for i := range customers {
		customers[i].BankAccounts = grouped[customers[i].ID]
	}
}

type transactionEnricher struct{ client model.TransactionClient }

func (e *transactionEnricher) Key() string       { return "transactions" }
func (e *transactionEnricher) DependsOn() string { return "bankAccounts" }

func (e *transactionEnricher) Enrich(customers []model.Customer) {
	var accountIDs []string
	for i := range customers {
		for j := range customers[i].BankAccounts {
			accountIDs = append(accountIDs, customers[i].BankAccounts[j].ID)
		}
	}
	grouped, err := e.client.GetByAccountIDs(accountIDs)
	if err != nil {
		return
	}
	for i := range customers {
		for j := range customers[i].BankAccounts {
			customers[i].BankAccounts[j].Transactions = grouped[customers[i].BankAccounts[j].ID]
		}
	}
}

type contactEnricher struct{ client model.ContactClient }

func (e *contactEnricher) Key() string       { return "contacts" }
func (e *contactEnricher) DependsOn() string { return "" }

func (e *contactEnricher) Enrich(customers []model.Customer) {
	ids := make([]string, len(customers))
	for i := range customers {
		ids[i] = customers[i].ID
	}
	grouped, err := e.client.GetByCustomerIDs(ids)
	if err != nil {
		return
	}
	for i := range customers {
		customers[i].Contacts = grouped[customers[i].ID]
	}
}
