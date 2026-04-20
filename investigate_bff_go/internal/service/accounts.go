package service

import (
	"context"

	"investigate_bff/internal/domain"
)

type AccountsService struct {
	accounts     accountDirectory
	holders      holderDirectory
	transactions transactionDirectory
}

func NewAccountsService(
	accounts accountDirectory,
	holders holderDirectory,
	transactions transactionDirectory,
) *AccountsService {
	return &AccountsService{
		accounts:     accounts,
		holders:      holders,
		transactions: transactions,
	}
}

func (s *AccountsService) List(ctx context.Context, cmd domain.ListAccountsCommand) (domain.PageResult[domain.AccountDetail], error) {
	cmd.Normalize()

	accounts, err := s.accounts.ListAccountDetails(ctx, cmd.Filter)
	if err != nil {
		return domain.PageResult[domain.AccountDetail]{}, err
	}

	pagedAccounts, pageInfo := domain.Paginate(accounts, cmd.Offset, cmd.Limit)
	if err := s.enrichAccounts(ctx, pagedAccounts, cmd.Includes); err != nil {
		return domain.PageResult[domain.AccountDetail]{}, err
	}

	return domain.PageResult[domain.AccountDetail]{
		Items:    pagedAccounts,
		HasMore:  pageInfo.HasMore,
		PageInfo: pageInfo,
	}, nil
}

func (s *AccountsService) enrichAccounts(ctx context.Context, accounts []domain.AccountDetail, includes map[string]bool) error {
	if len(accounts) == 0 || len(includes) == 0 {
		return nil
	}

	accountIDs := make([]string, len(accounts))
	for index := range accounts {
		accountIDs[index] = accounts[index].ID
	}

	var (
		holdersCh      <-chan asyncResult[map[string]domain.AccountHolder]
		transactionsCh <-chan asyncResult[map[string][]domain.Transaction]
	)

	if includes["holder"] {
		holdersCh = async(func() (map[string]domain.AccountHolder, error) {
			return s.holders.GetByAccountIDs(ctx, accountIDs)
		})
	}
	if includes["transactions"] {
		transactionsCh = async(func() (map[string][]domain.Transaction, error) {
			return s.transactions.GetByAccountIDs(ctx, accountIDs)
		})
	}

	holders := map[string]domain.AccountHolder{}
	transactions := map[string][]domain.Transaction{}

	if holdersCh != nil {
		result := <-holdersCh
		if result.err != nil {
			return result.err
		}
		holders = result.value
	}
	if transactionsCh != nil {
		result := <-transactionsCh
		if result.err != nil {
			return result.err
		}
		transactions = result.value
	}

	for index := range accounts {
		accountID := accounts[index].ID
		if includes["holder"] {
			if holder, ok := holders[accountID]; ok {
				accounts[index].Holder = &holder
			}
		}
		if includes["transactions"] {
			accounts[index].Transactions = transactions[accountID]
		}
	}

	return nil
}
