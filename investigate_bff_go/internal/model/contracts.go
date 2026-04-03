package model

// Client contracts — each represents one external data source call.

type AddressClient interface {
	GetByCustomerIDs(ids []string) (map[string][]Address, error)
}

type BankAccountClient interface {
	GetByCustomerIDs(ids []string) (map[string][]BankAccount, error)
}

type TransactionClient interface {
	GetByAccountIDs(ids []string) (map[string][]Transaction, error)
}

type ContactClient interface {
	GetByCustomerIDs(ids []string) (map[string][]Contact, error)
}

type HolderClient interface {
	GetByAccountIDs(ids []string) (map[string]AccountHolder, error)
}

// Enricher is the shared interface for the enrichment pipeline.
// Each enricher receives the root items and attaches its data.
// Same interface used across completely different endpoints.

type Enricher[T any] interface {
	Key() string
	DependsOn() string
	Enrich(items []T)
}
