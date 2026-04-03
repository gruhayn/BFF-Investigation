package mapper

import (
	"net/url"

	"investigate_bff/internal/model"
)

type AccountMapper struct{}

func NewAccountMapper() *AccountMapper { return &AccountMapper{} }

func (m *AccountMapper) ParseFilter(q url.Values) model.AccountDetailFilter {
	return model.AccountDetailFilter{
		ID:       q.Get("filter.id"),
		BankName: q.Get("filter.bankName"),
		Currency: q.Get("filter.currency"),
		Search:   q.Get("search"),
	}
}

func (m *AccountMapper) ParsePagination(q url.Values) (offset, limit int) {
	offset = parseNonNegativeInt(q.Get("page.offset"), 0)
	limit = parsePositiveInt(q.Get("page.limit"), 10)
	return
}
