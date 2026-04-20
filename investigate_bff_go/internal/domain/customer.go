package domain

type Customer struct {
	ID           string        `json:"id"`
	Name         string        `json:"name"`
	Email        string        `json:"email"`
	Addresses    []Address     `json:"addresses,omitempty"`
	BankAccounts []BankAccount `json:"bank_accounts,omitempty"`
	Contacts     []Contact     `json:"contacts,omitempty"`
}

type Address struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	Street     string `json:"street"`
	City       string `json:"city"`
	Country    string `json:"country"`
	ZipCode    string `json:"zip_code"`
}

type BankAccount struct {
	ID            string        `json:"id"`
	CustomerID    string        `json:"customer_id"`
	AccountNumber string        `json:"account_number"`
	BankName      string        `json:"bank_name"`
	Balance       float64       `json:"balance"`
	Currency      string        `json:"currency"`
	Transactions  []Transaction `json:"transactions,omitempty"`
}

type Transaction struct {
	ID          string  `json:"id"`
	AccountID   string  `json:"account_id"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
	Type        string  `json:"type"`
}

type Contact struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	Phone      string `json:"phone"`
	Type       string `json:"type"`
}

type CustomerFilter struct {
	ID     string
	Name   string
	Email  string
	Search string
}

type CustomerSummary struct {
	ID               string           `json:"id"`
	Name             string           `json:"name"`
	Email            string           `json:"email"`
	TotalBalance     float64          `json:"total_balance"`
	AccountCount     int              `json:"account_count"`
	TransactionCount int              `json:"transaction_count"`
	Addresses        []Address        `json:"addresses"`
	Contacts         []Contact        `json:"contacts"`
	RecentActivity   []TransactionRow `json:"recent_activity"`
}

type TransactionRow struct {
	TransactionID string  `json:"transaction_id"`
	AccountNumber string  `json:"account_number"`
	Amount        float64 `json:"amount"`
	Description   string  `json:"description"`
	Date          string  `json:"date"`
	Type          string  `json:"type"`
}
