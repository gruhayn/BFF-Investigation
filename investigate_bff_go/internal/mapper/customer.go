package mapper

import (
	"net/url"

	"investigate_bff/internal/model"
)

type CustomerMapper struct{}

func NewCustomerMapper() *CustomerMapper { return &CustomerMapper{} }

func (m *CustomerMapper) ParseFilter(q url.Values) model.CustomerFilter {
	return model.CustomerFilter{
		ID:     q.Get("filter.id"),
		Name:   q.Get("filter.name"),
		Email:  q.Get("filter.email"),
		Search: q.Get("search"),
	}
}

func (m *CustomerMapper) ParsePagination(q url.Values) (offset, limit int) {
	offset = parseNonNegativeInt(q.Get("page.offset"), 0)
	limit = parsePositiveInt(q.Get("page.limit"), 10)
	return
}
