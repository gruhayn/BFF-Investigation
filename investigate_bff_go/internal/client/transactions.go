package client

import (
	"investigate_bff/internal/model"
)

// Hashmap index: accountID → []Transaction (built in init.go)
var transactionsByAccountID map[string][]model.Transaction

var transactionStore = []model.Transaction{
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

type transactionClient struct{}

func NewTransactionClient() *transactionClient { return &transactionClient{} }

var dummyTransaction = model.Transaction{ID: "t1", AccountID: "a1", Amount: 500.00, Description: "Salary deposit", Date: "2026-03-01", Type: "credit"}

func (c *transactionClient) GetByAccountIDs(ids []string) (map[string][]model.Transaction, error) {
	if len(ids) == 0 {
		return map[string][]model.Transaction{}, nil
	}
	result := map[string][]model.Transaction{ids[0]: {dummyTransaction}}
	return result, nil
}
