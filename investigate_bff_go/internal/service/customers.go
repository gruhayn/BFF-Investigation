package service

import (
	"context"

	"investigate_bff/internal/domain"
)

type CustomersService struct {
	customers    customerDirectory
	addresses    addressDirectory
	accounts     accountDirectory
	transactions transactionDirectory
	contacts     contactDirectory
}

func NewCustomersService(
	customers customerDirectory,
	addresses addressDirectory,
	accounts accountDirectory,
	transactions transactionDirectory,
	contacts contactDirectory,
) *CustomersService {
	return &CustomersService{
		customers:    customers,
		addresses:    addresses,
		accounts:     accounts,
		transactions: transactions,
		contacts:     contacts,
	}
}

func (s *CustomersService) List(ctx context.Context, cmd domain.ListCustomersCommand) (domain.PageResult[domain.Customer], error) {
	cmd.Normalize()

	customers, err := s.customers.ListCustomers(ctx, cmd.Filter)
	if err != nil {
		return domain.PageResult[domain.Customer]{}, err
	}

	pagedCustomers, pageInfo := domain.Paginate(customers, cmd.Offset, cmd.Limit)
	if err := s.enrichCustomers(ctx, pagedCustomers, cmd.Includes); err != nil {
		return domain.PageResult[domain.Customer]{}, err
	}

	return domain.PageResult[domain.Customer]{
		Items:    pagedCustomers,
		HasMore:  pageInfo.HasMore,
		PageInfo: pageInfo,
	}, nil
}

func (s *CustomersService) enrichCustomers(ctx context.Context, customers []domain.Customer, includes map[string]bool) error {
	if len(customers) == 0 || len(includes) == 0 {
		return nil
	}

	customerIDs := make([]string, len(customers))
	for index := range customers {
		customerIDs[index] = customers[index].ID
	}

	type bankAccountsResponse struct {
		items map[string][]domain.BankAccount
		err   error
	}

	var (
		addressesCh <-chan asyncResult[map[string][]domain.Address]
		accountsCh  <-chan asyncResult[map[string][]domain.BankAccount]
		contactsCh  <-chan asyncResult[map[string][]domain.Contact]
	)

	if includes["addresses"] {
		addressesCh = async(func() (map[string][]domain.Address, error) {
			return s.addresses.GetByCustomerIDs(ctx, customerIDs)
		})
	}
	if includes["bank_accounts"] || includes["transactions"] {
		accountsCh = async(func() (map[string][]domain.BankAccount, error) {
			return s.accounts.GetByCustomerIDs(ctx, customerIDs)
		})
	}
	if includes["contacts"] {
		contactsCh = async(func() (map[string][]domain.Contact, error) {
			return s.contacts.GetByCustomerIDs(ctx, customerIDs)
		})
	}

	addresses := map[string][]domain.Address{}
	bankAccounts := map[string][]domain.BankAccount{}
	contacts := map[string][]domain.Contact{}

	if addressesCh != nil {
		result := <-addressesCh
		if result.err != nil {
			return result.err
		}
		addresses = result.value
	}
	if accountsCh != nil {
		result := <-accountsCh
		if result.err != nil {
			return result.err
		}
		bankAccounts = result.value
	}
	if contactsCh != nil {
		result := <-contactsCh
		if result.err != nil {
			return result.err
		}
		contacts = result.value
	}

	if includes["transactions"] {
		accountIDs := make([]string, 0)
		for _, customerAccounts := range bankAccounts {
			for _, account := range customerAccounts {
				accountIDs = append(accountIDs, account.ID)
			}
		}

		transactions, err := s.transactions.GetByAccountIDs(ctx, accountIDs)
		if err != nil {
			return err
		}

		for customerID, customerAccounts := range bankAccounts {
			for index := range customerAccounts {
				customerAccounts[index].Transactions = transactions[customerAccounts[index].ID]
			}
			bankAccounts[customerID] = customerAccounts
		}
	}

	for index := range customers {
		customerID := customers[index].ID
		if includes["addresses"] {
			customers[index].Addresses = addresses[customerID]
		}
		if includes["bank_accounts"] || includes["transactions"] {
			customers[index].BankAccounts = bankAccounts[customerID]
		}
		if includes["contacts"] {
			customers[index].Contacts = contacts[customerID]
		}
	}

	return nil
}
