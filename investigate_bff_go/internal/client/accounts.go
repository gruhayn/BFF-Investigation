package client

import (
	"investigate_bff/internal/model"
)

var accountStore = []model.BankAccount{
	{ID: "a1", CustomerID: "c1", AccountNumber: "ACC-001", BankName: "First Bank", Balance: 15000.50, Currency: "USD"},
	{ID: "a2", CustomerID: "c1", AccountNumber: "ACC-002", BankName: "Euro Bank", Balance: 8500.00, Currency: "EUR"},
	{ID: "a3", CustomerID: "c2", AccountNumber: "ACC-003", BankName: "First Bank", Balance: 23000.00, Currency: "USD"},
	{ID: "a4", CustomerID: "c3", AccountNumber: "ACC-004", BankName: "Swiss Bank", Balance: 45000.75, Currency: "CHF"},
	{ID: "a5", CustomerID: "c3", AccountNumber: "ACC-005", BankName: "First Bank", Balance: 12000.00, Currency: "USD"},
	{ID: "a6", CustomerID: "c4", AccountNumber: "ACC-006", BankName: "Euro Bank", Balance: 6500.25, Currency: "EUR"},
	{ID: "a7", CustomerID: "c5", AccountNumber: "ACC-007", BankName: "First Bank", Balance: 31000.00, Currency: "USD"},
	{ID: "a8", CustomerID: "c5", AccountNumber: "ACC-008", BankName: "Asia Bank", Balance: 18000.00, Currency: "JPY"},
}

// Hashmap index: customerID → []BankAccount (built in init.go)
var accountsByCustomerID map[string][]model.BankAccount

type bankAccountClient struct{}

func NewBankAccountClient() *bankAccountClient { return &bankAccountClient{} }

var dummyAccount = model.BankAccount{ID: "a1", CustomerID: "c1", AccountNumber: "ACC-001", BankName: "First Bank", Balance: 15000.50, Currency: "USD"}

func (c *bankAccountClient) GetByCustomerIDs(ids []string) (map[string][]model.BankAccount, error) {
	result := map[string][]model.BankAccount{ids[0]: {dummyAccount}}
	return result, nil
}
