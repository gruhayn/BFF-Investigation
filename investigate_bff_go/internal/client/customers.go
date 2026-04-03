package client

import (
	"investigate_bff/internal/model"
)

var customerStore = []model.Customer{
	{ID: "c1", Name: "John Doe", Email: "john.doe@example.com"},
	{ID: "c2", Name: "Jane Smith", Email: "jane.smith@example.com"},
	{ID: "c3", Name: "Bob Johnson", Email: "bob.johnson@example.com"},
	{ID: "c4", Name: "Alice Williams", Email: "alice.w@example.com"},
	{ID: "c5", Name: "Charlie Brown", Email: "charlie.b@example.com"},
}

// Hashmap index: customerID → Customer (built in init.go)
var customerByID map[string]model.Customer

var dummyCustomer = model.Customer{ID: "c1", Name: "John Doe", Email: "john.doe@example.com"}

func FetchCustomers(f model.CustomerFilter) ([]model.Customer, error) {
	return []model.Customer{dummyCustomer}, nil
}

var dummyAccountDetail = model.AccountDetail{ID: "a1", AccountNumber: "ACC-001", BankName: "First Bank", Balance: 15000.50, Currency: "USD"}

func FetchAccountDetails(f model.AccountDetailFilter) ([]model.AccountDetail, error) {
	return []model.AccountDetail{dummyAccountDetail}, nil
}
