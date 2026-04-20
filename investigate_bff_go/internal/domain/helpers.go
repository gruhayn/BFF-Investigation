package domain

import "sort"

func Paginate[T any](items []T, offset, limit int) ([]T, PageInfo) {
	if items == nil {
		items = []T{}
	}

	total := len(items)
	if offset > total {
		offset = total
	}

	end := offset + limit
	if end > total {
		end = total
	}

	return items[offset:end], PageInfo{
		TotalCount: total,
		Offset:     offset,
		Limit:      limit,
		HasMore:    end < total,
	}
}

func BuildCustomerSummary(
	customer Customer,
	addresses []Address,
	accounts []BankAccount,
	txnsByAccount map[string][]Transaction,
	contacts []Contact,
) CustomerSummary {
	var totalBalance float64
	var transactionCount int
	rows := make([]TransactionRow, 0)
	accountNumbers := make(map[string]string, len(accounts))

	for _, account := range accounts {
		totalBalance += account.Balance
		accountNumbers[account.ID] = account.AccountNumber
	}

	for accountID, transactions := range txnsByAccount {
		transactionCount += len(transactions)
		for _, transaction := range transactions {
			rows = append(rows, TransactionRow{
				TransactionID: transaction.ID,
				AccountNumber: accountNumbers[accountID],
				Amount:        transaction.Amount,
				Description:   transaction.Description,
				Date:          transaction.Date,
				Type:          transaction.Type,
			})
		}
	}

	sort.Slice(rows, func(i, j int) bool {
		return rows[i].Date > rows[j].Date
	})

	if len(rows) > 5 {
		rows = rows[:5]
	}

	return CustomerSummary{
		ID:               customer.ID,
		Name:             customer.Name,
		Email:            customer.Email,
		TotalBalance:     totalBalance,
		AccountCount:     len(accounts),
		TransactionCount: transactionCount,
		Addresses:        addresses,
		Contacts:         contacts,
		RecentActivity:   rows,
	}
}

func cloneIncludes(includes map[string]bool) map[string]bool {
	if len(includes) == 0 {
		return map[string]bool{}
	}

	cloned := make(map[string]bool, len(includes))
	for key, value := range includes {
		cloned[key] = value
	}
	return cloned
}
