package client

import (
	"fmt"
	"investigate_bff/internal/model"
)

func init() {
	customerStore = multiply(customerStore, 100, func(c model.Customer, i int) model.Customer {
		c.ID = fmt.Sprintf("%s_%d", c.ID, i)
		c.Email = fmt.Sprintf("%s_%d", c.Email, i)
		return c
	})
	// Keep original IDs (c1–c5) queryable by re-adding them
	customerStore = append([]model.Customer{
		{ID: "c1", Name: "John Doe", Email: "john.doe@example.com"},
		{ID: "c2", Name: "Jane Smith", Email: "jane.smith@example.com"},
		{ID: "c3", Name: "Bob Johnson", Email: "bob.johnson@example.com"},
		{ID: "c4", Name: "Alice Williams", Email: "alice.w@example.com"},
		{ID: "c5", Name: "Charlie Brown", Email: "charlie.b@example.com"},
	}, customerStore...)

	accountStore = multiply(accountStore, 100, func(a model.BankAccount, i int) model.BankAccount {
		a.ID = fmt.Sprintf("%s_%d", a.ID, i)
		a.CustomerID = fmt.Sprintf("%s_%d", a.CustomerID, i)
		a.AccountNumber = fmt.Sprintf("%s_%d", a.AccountNumber, i)
		return a
	})
	// Keep originals for c1–c5
	accountStore = append([]model.BankAccount{
		{ID: "a1", CustomerID: "c1", AccountNumber: "ACC-001", BankName: "First Bank", Balance: 15000.50, Currency: "USD"},
		{ID: "a2", CustomerID: "c1", AccountNumber: "ACC-002", BankName: "Euro Bank", Balance: 8500.00, Currency: "EUR"},
		{ID: "a3", CustomerID: "c2", AccountNumber: "ACC-003", BankName: "First Bank", Balance: 23000.00, Currency: "USD"},
		{ID: "a4", CustomerID: "c3", AccountNumber: "ACC-004", BankName: "Swiss Bank", Balance: 45000.75, Currency: "CHF"},
		{ID: "a5", CustomerID: "c3", AccountNumber: "ACC-005", BankName: "First Bank", Balance: 12000.00, Currency: "USD"},
		{ID: "a6", CustomerID: "c4", AccountNumber: "ACC-006", BankName: "Euro Bank", Balance: 6500.25, Currency: "EUR"},
		{ID: "a7", CustomerID: "c5", AccountNumber: "ACC-007", BankName: "First Bank", Balance: 31000.00, Currency: "USD"},
		{ID: "a8", CustomerID: "c5", AccountNumber: "ACC-008", BankName: "Asia Bank", Balance: 18000.00, Currency: "JPY"},
	}, accountStore...)

	addressStore = multiply(addressStore, 100, func(a model.Address, i int) model.Address {
		a.ID = fmt.Sprintf("%s_%d", a.ID, i)
		a.CustomerID = fmt.Sprintf("%s_%d", a.CustomerID, i)
		return a
	})
	addressStore = append([]model.Address{
		{ID: "addr1", CustomerID: "c1", Street: "123 Main St", City: "New York", Country: "USA", ZipCode: "10001"},
		{ID: "addr2", CustomerID: "c1", Street: "456 Park Ave", City: "New York", Country: "USA", ZipCode: "10002"},
		{ID: "addr3", CustomerID: "c2", Street: "789 Oak Rd", City: "London", Country: "UK", ZipCode: "SW1A 1AA"},
		{ID: "addr4", CustomerID: "c3", Street: "321 Pine St", City: "Berlin", Country: "Germany", ZipCode: "10115"},
		{ID: "addr5", CustomerID: "c4", Street: "654 Elm Blvd", City: "Paris", Country: "France", ZipCode: "75001"},
		{ID: "addr6", CustomerID: "c4", Street: "987 Cedar Ln", City: "Lyon", Country: "France", ZipCode: "69001"},
		{ID: "addr7", CustomerID: "c5", Street: "111 Maple Dr", City: "Tokyo", Country: "Japan", ZipCode: "100-0001"},
	}, addressStore...)

	transactionStore = multiply(transactionStore, 100, func(t model.Transaction, i int) model.Transaction {
		t.ID = fmt.Sprintf("%s_%d", t.ID, i)
		t.AccountID = fmt.Sprintf("%s_%d", t.AccountID, i)
		return t
	})
	transactionStore = append([]model.Transaction{
		{ID: "t1", AccountID: "a1", Amount: 500.00, Description: "Salary deposit", Date: "2026-03-01", Type: "credit"},
		{ID: "t2", AccountID: "a1", Amount: 120.50, Description: "Grocery store", Date: "2026-03-05", Type: "debit"},
		{ID: "t3", AccountID: "a1", Amount: 75.00, Description: "Electric bill", Date: "2026-03-10", Type: "debit"},
		{ID: "t4", AccountID: "a2", Amount: 1000.00, Description: "Transfer in", Date: "2026-03-02", Type: "credit"},
		{ID: "t5", AccountID: "a2", Amount: 200.00, Description: "Online shopping", Date: "2026-03-08", Type: "debit"},
		{ID: "t6", AccountID: "a3", Amount: 3000.00, Description: "Salary deposit", Date: "2026-03-01", Type: "credit"},
		{ID: "t7", AccountID: "a3", Amount: 450.00, Description: "Restaurant", Date: "2026-03-12", Type: "debit"},
		{ID: "t8", AccountID: "a4", Amount: 5000.00, Description: "Investment return", Date: "2026-03-03", Type: "credit"},
		{ID: "t9", AccountID: "a4", Amount: 800.00, Description: "Insurance", Date: "2026-03-07", Type: "debit"},
		{ID: "t10", AccountID: "a5", Amount: 150.00, Description: "Subscription", Date: "2026-03-04", Type: "debit"},
		{ID: "t11", AccountID: "a6", Amount: 2500.00, Description: "Freelance payment", Date: "2026-03-06", Type: "credit"},
		{ID: "t12", AccountID: "a7", Amount: 4200.00, Description: "Salary deposit", Date: "2026-03-01", Type: "credit"},
		{ID: "t13", AccountID: "a7", Amount: 350.00, Description: "Gas station", Date: "2026-03-09", Type: "debit"},
		{ID: "t14", AccountID: "a8", Amount: 1500.00, Description: "Transfer in", Date: "2026-03-02", Type: "credit"},
		{ID: "t15", AccountID: "a8", Amount: 600.00, Description: "Electronics", Date: "2026-03-11", Type: "debit"},
	}, transactionStore...)

	contactStore = multiply(contactStore, 100, func(c model.Contact, i int) model.Contact {
		c.ID = fmt.Sprintf("%s_%d", c.ID, i)
		c.CustomerID = fmt.Sprintf("%s_%d", c.CustomerID, i)
		return c
	})
	contactStore = append([]model.Contact{
		{ID: "con1", CustomerID: "c1", Phone: "+1-555-0101", Type: "mobile"},
		{ID: "con2", CustomerID: "c1", Phone: "+1-555-0102", Type: "work"},
		{ID: "con3", CustomerID: "c2", Phone: "+44-20-1234", Type: "home"},
		{ID: "con4", CustomerID: "c2", Phone: "+44-20-5678", Type: "mobile"},
		{ID: "con5", CustomerID: "c3", Phone: "+49-30-9876", Type: "work"},
		{ID: "con6", CustomerID: "c4", Phone: "+33-1-4321", Type: "mobile"},
		{ID: "con7", CustomerID: "c5", Phone: "+81-3-5555", Type: "home"},
		{ID: "con8", CustomerID: "c5", Phone: "+81-3-6666", Type: "work"},
	}, contactStore...)

	// Build hashmap indexes for O(1) lookups
	customerByID = make(map[string]model.Customer, len(customerStore))
	for _, c := range customerStore {
		customerByID[c.ID] = c
	}

	accountsByCustomerID = make(map[string][]model.BankAccount)
	for _, a := range accountStore {
		accountsByCustomerID[a.CustomerID] = append(accountsByCustomerID[a.CustomerID], a)
	}

	addressesByCustomerID = make(map[string][]model.Address)
	for _, a := range addressStore {
		addressesByCustomerID[a.CustomerID] = append(addressesByCustomerID[a.CustomerID], a)
	}

	transactionsByAccountID = make(map[string][]model.Transaction)
	for _, t := range transactionStore {
		transactionsByAccountID[t.AccountID] = append(transactionsByAccountID[t.AccountID], t)
	}

	contactsByCustomerID = make(map[string][]model.Contact)
	for _, c := range contactStore {
		contactsByCustomerID[c.CustomerID] = append(contactsByCustomerID[c.CustomerID], c)
	}

	// holder indexes: accountID → customerID, customerID → holder
	acctToCustomerIndex = make(map[string]string, len(accountStore))
	for _, a := range accountStore {
		acctToCustomerIndex[a.ID] = a.CustomerID
	}
	holderByCustomerID = make(map[string]model.AccountHolder, len(customerStore))
	for _, c := range customerStore {
		holderByCustomerID[c.ID] = model.AccountHolder{ID: c.ID, Name: c.Name, Email: c.Email}
	}

	fmt.Printf("[INIT] Stores expanded: customers=%d accounts=%d addresses=%d transactions=%d contacts=%d\n",
		len(customerStore), len(accountStore), len(addressStore), len(transactionStore), len(contactStore))
	fmt.Println("[INIT] Hashmap indexes built")
}

func multiply[T any](src []T, times int, mutate func(T, int) T) []T {
	out := make([]T, 0, len(src)*times)
	for i := 1; i <= times; i++ {
		for _, item := range src {
			out = append(out, mutate(item, i))
		}
	}
	return out
}
