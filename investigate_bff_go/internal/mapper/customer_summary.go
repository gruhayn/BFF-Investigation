package mapper

import (
	"sort"

	"investigate_bff/internal/model"
)

type CustomerSummaryMapper struct{}

func NewCustomerSummaryMapper() *CustomerSummaryMapper { return &CustomerSummaryMapper{} }

// MapSummary combines results from 4 different clients into a single CustomerSummary.
func (m *CustomerSummaryMapper) MapSummary(
	customer model.Customer,
	addresses []model.Address,
	accounts []model.BankAccount,
	txnsByAccount map[string][]model.Transaction,
	contacts []model.Contact,
) model.CustomerSummary {
	var totalBalance float64
	var txnCount int
	var rows []model.TransactionRow

	acctNumByID := make(map[string]string, len(accounts))
	for _, a := range accounts {
		totalBalance += a.Balance
		acctNumByID[a.ID] = a.AccountNumber
	}

	for acctID, txns := range txnsByAccount {
		txnCount += len(txns)
		for _, t := range txns {
			rows = append(rows, model.TransactionRow{
				TransactionID: t.ID,
				AccountNumber: acctNumByID[acctID],
				Amount:        t.Amount,
				Description:   t.Description,
				Date:          t.Date,
				Type:          t.Type,
			})
		}
	}

	// Sort by date descending, keep latest 5
	sort.Slice(rows, func(i, j int) bool { return rows[i].Date > rows[j].Date })
	if len(rows) > 5 {
		rows = rows[:5]
	}

	return model.CustomerSummary{
		ID:               customer.ID,
		Name:             customer.Name,
		Email:            customer.Email,
		TotalBalance:     totalBalance,
		AccountCount:     len(accounts),
		TransactionCount: txnCount,
		Addresses:        addresses,
		Contacts:         contacts,
		RecentActivity:   rows,
	}
}
