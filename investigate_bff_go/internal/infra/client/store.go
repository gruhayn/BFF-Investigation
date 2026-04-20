package client

import (
	"fmt"
	"strings"

	"investigate_bff/internal/domain"
)

type store struct {
	customers             []domain.Customer
	customerByID          map[string]domain.Customer
	accounts              []domain.BankAccount
	accountDetails        []domain.AccountDetail
	accountsByCustomerID  map[string][]domain.BankAccount
	addressesByCustomerID map[string][]domain.Address
	transactionsByAccount map[string][]domain.Transaction
	contactsByCustomerID  map[string][]domain.Contact
	holderByCustomerID    map[string]domain.AccountHolder
	accountToCustomerID   map[string]string
}

func newStore() *store {
	customers := []domain.Customer{
		{ID: "c1", Name: "John Doe", Email: "john.doe@example.com"},
		{ID: "c2", Name: "Jane Smith", Email: "jane.smith@example.com"},
		{ID: "c3", Name: "Bob Johnson", Email: "bob.johnson@example.com"},
		{ID: "c4", Name: "Alice Williams", Email: "alice.w@example.com"},
		{ID: "c5", Name: "Charlie Brown", Email: "charlie.b@example.com"},
	}
	customers = append(customers, multiply(customers, 100, func(customer domain.Customer, index int) domain.Customer {
		customer.ID = fmt.Sprintf("%s_%d", customer.ID, index)
		customer.Email = fmt.Sprintf("%s_%d", customer.Email, index)
		return customer
	})...)

	accounts := []domain.BankAccount{
		{ID: "a1", CustomerID: "c1", AccountNumber: "ACC-001", BankName: "First Bank", Balance: 15000.50, Currency: "USD"},
		{ID: "a2", CustomerID: "c1", AccountNumber: "ACC-002", BankName: "Euro Bank", Balance: 8500.00, Currency: "EUR"},
		{ID: "a3", CustomerID: "c2", AccountNumber: "ACC-003", BankName: "First Bank", Balance: 23000.00, Currency: "USD"},
		{ID: "a4", CustomerID: "c3", AccountNumber: "ACC-004", BankName: "Swiss Bank", Balance: 45000.75, Currency: "CHF"},
		{ID: "a5", CustomerID: "c3", AccountNumber: "ACC-005", BankName: "First Bank", Balance: 12000.00, Currency: "USD"},
		{ID: "a6", CustomerID: "c4", AccountNumber: "ACC-006", BankName: "Euro Bank", Balance: 6500.25, Currency: "EUR"},
		{ID: "a7", CustomerID: "c5", AccountNumber: "ACC-007", BankName: "First Bank", Balance: 31000.00, Currency: "USD"},
		{ID: "a8", CustomerID: "c5", AccountNumber: "ACC-008", BankName: "Asia Bank", Balance: 18000.00, Currency: "JPY"},
	}
	accounts = append(accounts, multiply(accounts, 100, func(account domain.BankAccount, index int) domain.BankAccount {
		account.ID = fmt.Sprintf("%s_%d", account.ID, index)
		account.CustomerID = fmt.Sprintf("%s_%d", account.CustomerID, index)
		account.AccountNumber = fmt.Sprintf("%s_%d", account.AccountNumber, index)
		return account
	})...)

	addresses := []domain.Address{
		{ID: "addr1", CustomerID: "c1", Street: "123 Main St", City: "New York", Country: "USA", ZipCode: "10001"},
		{ID: "addr2", CustomerID: "c1", Street: "456 Park Ave", City: "New York", Country: "USA", ZipCode: "10002"},
		{ID: "addr3", CustomerID: "c2", Street: "789 Oak Rd", City: "London", Country: "UK", ZipCode: "SW1A 1AA"},
		{ID: "addr4", CustomerID: "c3", Street: "321 Pine St", City: "Berlin", Country: "Germany", ZipCode: "10115"},
		{ID: "addr5", CustomerID: "c4", Street: "654 Elm Blvd", City: "Paris", Country: "France", ZipCode: "75001"},
		{ID: "addr6", CustomerID: "c4", Street: "987 Cedar Ln", City: "Lyon", Country: "France", ZipCode: "69001"},
		{ID: "addr7", CustomerID: "c5", Street: "111 Maple Dr", City: "Tokyo", Country: "Japan", ZipCode: "100-0001"},
	}
	addresses = append(addresses, multiply(addresses, 100, func(address domain.Address, index int) domain.Address {
		address.ID = fmt.Sprintf("%s_%d", address.ID, index)
		address.CustomerID = fmt.Sprintf("%s_%d", address.CustomerID, index)
		return address
	})...)

	transactions := []domain.Transaction{
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
	}
	transactions = append(transactions, multiply(transactions, 100, func(transaction domain.Transaction, index int) domain.Transaction {
		transaction.ID = fmt.Sprintf("%s_%d", transaction.ID, index)
		transaction.AccountID = fmt.Sprintf("%s_%d", transaction.AccountID, index)
		return transaction
	})...)

	contacts := []domain.Contact{
		{ID: "con1", CustomerID: "c1", Phone: "+1-555-0101", Type: "mobile"},
		{ID: "con2", CustomerID: "c1", Phone: "+1-555-0102", Type: "work"},
		{ID: "con3", CustomerID: "c2", Phone: "+44-20-1234", Type: "home"},
		{ID: "con4", CustomerID: "c2", Phone: "+44-20-5678", Type: "mobile"},
		{ID: "con5", CustomerID: "c3", Phone: "+49-30-9876", Type: "work"},
		{ID: "con6", CustomerID: "c4", Phone: "+33-1-4321", Type: "mobile"},
		{ID: "con7", CustomerID: "c5", Phone: "+81-3-5555", Type: "home"},
		{ID: "con8", CustomerID: "c5", Phone: "+81-3-6666", Type: "work"},
	}
	contacts = append(contacts, multiply(contacts, 100, func(contact domain.Contact, index int) domain.Contact {
		contact.ID = fmt.Sprintf("%s_%d", contact.ID, index)
		contact.CustomerID = fmt.Sprintf("%s_%d", contact.CustomerID, index)
		return contact
	})...)

	customerByID := make(map[string]domain.Customer, len(customers))
	for _, customer := range customers {
		customerByID[customer.ID] = customer
	}

	accountsByCustomerID := make(map[string][]domain.BankAccount)
	accountDetails := make([]domain.AccountDetail, 0, len(accounts))
	accountToCustomerID := make(map[string]string, len(accounts))
	for _, account := range accounts {
		accountsByCustomerID[account.CustomerID] = append(accountsByCustomerID[account.CustomerID], account)
		accountDetails = append(accountDetails, domain.AccountDetail{
			ID:            account.ID,
			AccountNumber: account.AccountNumber,
			BankName:      account.BankName,
			Balance:       account.Balance,
			Currency:      account.Currency,
		})
		accountToCustomerID[account.ID] = account.CustomerID
	}

	addressesByCustomerID := make(map[string][]domain.Address)
	for _, address := range addresses {
		addressesByCustomerID[address.CustomerID] = append(addressesByCustomerID[address.CustomerID], address)
	}

	transactionsByAccount := make(map[string][]domain.Transaction)
	for _, transaction := range transactions {
		transactionsByAccount[transaction.AccountID] = append(transactionsByAccount[transaction.AccountID], transaction)
	}

	contactsByCustomerID := make(map[string][]domain.Contact)
	for _, contact := range contacts {
		contactsByCustomerID[contact.CustomerID] = append(contactsByCustomerID[contact.CustomerID], contact)
	}

	holderByCustomerID := make(map[string]domain.AccountHolder, len(customers))
	for _, customer := range customers {
		holderByCustomerID[customer.ID] = domain.AccountHolder{
			ID:    customer.ID,
			Name:  customer.Name,
			Email: customer.Email,
		}
	}

	return &store{
		customers:             customers,
		customerByID:          customerByID,
		accounts:              accounts,
		accountDetails:        accountDetails,
		accountsByCustomerID:  accountsByCustomerID,
		addressesByCustomerID: addressesByCustomerID,
		transactionsByAccount: transactionsByAccount,
		contactsByCustomerID:  contactsByCustomerID,
		holderByCustomerID:    holderByCustomerID,
		accountToCustomerID:   accountToCustomerID,
	}
}

func matchesCustomerFilter(customer domain.Customer, filter domain.CustomerFilter) bool {
	if filter.ID != "" && customer.ID != filter.ID {
		return false
	}
	if filter.Name != "" && !strings.Contains(strings.ToLower(customer.Name), strings.ToLower(filter.Name)) {
		return false
	}
	if filter.Email != "" && !strings.Contains(strings.ToLower(customer.Email), strings.ToLower(filter.Email)) {
		return false
	}
	if filter.Search != "" {
		search := strings.ToLower(filter.Search)
		if !strings.Contains(strings.ToLower(customer.Name), search) && !strings.Contains(strings.ToLower(customer.Email), search) {
			return false
		}
	}
	return true
}

func matchesAccountFilter(account domain.AccountDetail, filter domain.AccountDetailFilter) bool {
	if filter.ID != "" && account.ID != filter.ID {
		return false
	}
	if filter.BankName != "" && !strings.Contains(strings.ToLower(account.BankName), strings.ToLower(filter.BankName)) {
		return false
	}
	if filter.Currency != "" && !strings.EqualFold(account.Currency, filter.Currency) {
		return false
	}
	if filter.Search != "" {
		search := strings.ToLower(filter.Search)
		if !strings.Contains(strings.ToLower(account.AccountNumber), search) &&
			!strings.Contains(strings.ToLower(account.BankName), search) &&
			!strings.Contains(strings.ToLower(account.Currency), search) {
			return false
		}
	}
	return true
}

func copyCustomers(customers []domain.Customer) []domain.Customer {
	cloned := make([]domain.Customer, len(customers))
	copy(cloned, customers)
	return cloned
}

func copyBankAccounts(accounts []domain.BankAccount) []domain.BankAccount {
	cloned := make([]domain.BankAccount, len(accounts))
	copy(cloned, accounts)
	return cloned
}

func copyAddresses(addresses []domain.Address) []domain.Address {
	cloned := make([]domain.Address, len(addresses))
	copy(cloned, addresses)
	return cloned
}

func copyTransactions(transactions []domain.Transaction) []domain.Transaction {
	cloned := make([]domain.Transaction, len(transactions))
	copy(cloned, transactions)
	return cloned
}

func copyContacts(contacts []domain.Contact) []domain.Contact {
	cloned := make([]domain.Contact, len(contacts))
	copy(cloned, contacts)
	return cloned
}

func copyAccountDetails(accounts []domain.AccountDetail) []domain.AccountDetail {
	cloned := make([]domain.AccountDetail, len(accounts))
	copy(cloned, accounts)
	return cloned
}

func multiply[T any](items []T, times int, mutate func(T, int) T) []T {
	cloned := make([]T, 0, len(items)*times)
	for index := 1; index <= times; index++ {
		for _, item := range items {
			cloned = append(cloned, mutate(item, index))
		}
	}
	return cloned
}
