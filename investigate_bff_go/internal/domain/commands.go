package domain

import "strings"

type ListCustomersCommand struct {
	Filter   CustomerFilter
	Offset   int
	Limit    int
	Includes map[string]bool
}

func (c *ListCustomersCommand) Normalize() {
	c.Filter.ID = strings.TrimSpace(c.Filter.ID)
	c.Filter.Name = strings.TrimSpace(c.Filter.Name)
	c.Filter.Email = strings.TrimSpace(strings.ToLower(c.Filter.Email))
	c.Filter.Search = strings.TrimSpace(strings.ToLower(c.Filter.Search))
	if c.Offset < 0 {
		c.Offset = 0
	}
	if c.Limit <= 0 {
		c.Limit = 10
	}
	c.Includes = cloneIncludes(c.Includes)
}

type ListAccountsCommand struct {
	Filter   AccountDetailFilter
	Offset   int
	Limit    int
	Includes map[string]bool
}

func (c *ListAccountsCommand) Normalize() {
	c.Filter.ID = strings.TrimSpace(c.Filter.ID)
	c.Filter.BankName = strings.TrimSpace(strings.ToLower(c.Filter.BankName))
	c.Filter.Currency = strings.TrimSpace(strings.ToUpper(c.Filter.Currency))
	c.Filter.Search = strings.TrimSpace(strings.ToLower(c.Filter.Search))
	if c.Offset < 0 {
		c.Offset = 0
	}
	if c.Limit <= 0 {
		c.Limit = 10
	}
	c.Includes = cloneIncludes(c.Includes)
}

type GetCustomerSummaryCommand struct {
	CustomerID string
}

func (c *GetCustomerSummaryCommand) Normalize() {
	c.CustomerID = strings.TrimSpace(c.CustomerID)
}
