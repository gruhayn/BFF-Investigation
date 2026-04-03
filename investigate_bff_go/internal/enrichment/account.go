package enrichment

import (
	"investigate_bff/internal/client"
	"investigate_bff/internal/model"
)

func NewAccountDetailEnrichers() []model.Enricher[model.AccountDetail] {
	return []model.Enricher[model.AccountDetail]{
		&holderEnricher{client: client.Registry.HolderClient},
		&accountTxnEnricher{client: client.Registry.TransactionClient},
	}
}

type holderEnricher struct{ client model.HolderClient }

func (e *holderEnricher) Key() string       { return "holder" }
func (e *holderEnricher) DependsOn() string { return "" }

func (e *holderEnricher) Enrich(accounts []model.AccountDetail) {
	ids := make([]string, len(accounts))
	for i := range accounts {
		ids[i] = accounts[i].ID
	}
	holders, err := e.client.GetByAccountIDs(ids)
	if err != nil {
		return
	}
	for i := range accounts {
		if h, ok := holders[accounts[i].ID]; ok {
			accounts[i].Holder = &h
		}
	}
}

type accountTxnEnricher struct{ client model.TransactionClient }

func (e *accountTxnEnricher) Key() string       { return "transactions" }
func (e *accountTxnEnricher) DependsOn() string { return "" }

func (e *accountTxnEnricher) Enrich(accounts []model.AccountDetail) {
	ids := make([]string, len(accounts))
	for i := range accounts {
		ids[i] = accounts[i].ID
	}
	grouped, err := e.client.GetByAccountIDs(ids)
	if err != nil {
		return
	}
	for i := range accounts {
		accounts[i].Transactions = grouped[accounts[i].ID]
	}
}
