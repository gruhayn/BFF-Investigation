package model

// /customers endpoint - all models

type Customer struct {
	ID           string        `json:"id"`
	Name         string        `json:"name"`
	Email        string        `json:"email"`
	Addresses    []Address     `json:"addresses,omitempty"`
	BankAccounts []BankAccount `json:"bankAccounts,omitempty"`
	Contacts     []Contact     `json:"contacts,omitempty"`
}

type Address struct {
	ID         string `json:"id"`
	CustomerID string `json:"customerId"`
	Street     string `json:"street"`
	City       string `json:"city"`
	Country    string `json:"country"`
	ZipCode    string `json:"zipCode"`
}

type BankAccount struct {
	ID            string        `json:"id"`
	CustomerID    string        `json:"customerId"`
	AccountNumber string        `json:"accountNumber"`
	BankName      string        `json:"bankName"`
	Balance       float64       `json:"balance"`
	Currency      string        `json:"currency"`
	Transactions  []Transaction `json:"transactions,omitempty"`
}

type Transaction struct {
	ID          string  `json:"id"`
	AccountID   string  `json:"accountId"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
	Type        string  `json:"type"`
}

type Contact struct {
	ID         string `json:"id"`
	CustomerID string `json:"customerId"`
	Phone      string `json:"phone"`
	Type       string `json:"type"`
}

type CustomerFilter struct {
	ID     string
	Name   string
	Email  string
	Search string
}

// CustomerSummary — composite response built from multiple client calls.
type CustomerSummary struct {
	ID               string           `json:"id"`
	Name             string           `json:"name"`
	Email            string           `json:"email"`
	TotalBalance     float64          `json:"totalBalance"`
	AccountCount     int              `json:"accountCount"`
	TransactionCount int              `json:"transactionCount"`
	Addresses        []Address        `json:"addresses"`
	Contacts         []Contact        `json:"contacts"`
	RecentActivity   []TransactionRow `json:"recentActivity"`
}

// TransactionRow is a flattened transaction with account info for the summary view.
type TransactionRow struct {
	TransactionID string  `json:"transactionId"`
	AccountNumber string  `json:"accountNumber"`
	Amount        float64 `json:"amount"`
	Description   string  `json:"description"`
	Date          string  `json:"date"`
	Type          string  `json:"type"`
}
