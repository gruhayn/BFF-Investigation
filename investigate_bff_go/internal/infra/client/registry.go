package client

type Registry struct {
	Customers    *CustomerClient
	Accounts     *AccountClient
	Addresses    *AddressClient
	Transactions *TransactionClient
	Contacts     *ContactClient
	Holders      *HolderClient
}

func NewRegistry() *Registry {
	store := newStore()

	return &Registry{
		Customers:    &CustomerClient{store: store},
		Accounts:     &AccountClient{store: store},
		Addresses:    &AddressClient{store: store},
		Transactions: &TransactionClient{store: store},
		Contacts:     &ContactClient{store: store},
		Holders:      &HolderClient{store: store},
	}
}
