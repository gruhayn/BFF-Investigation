package service

import "investigate_bff/internal/domain"

func buildCustomer(id string) domain.Customer {
	return domain.Customer{
		ID:    id,
		Name:  "Customer " + id,
		Email: id + "@example.com",
	}
}

func buildBankAccount(id string, customerID string) domain.BankAccount {
	return domain.BankAccount{
		ID:            id,
		CustomerID:    customerID,
		AccountNumber: "ACC-" + id,
		BankName:      "First Bank",
		Balance:       100,
		Currency:      "USD",
	}
}
