package handler

import (
	"net/http"
	"strconv"
	"strings"

	"investigate_bff/internal/domain"
)

type badRequestError struct {
	message string
}

func (e *badRequestError) Error() string {
	return e.message
}

func parseListCustomersRequest(r *http.Request) (domain.ListCustomersCommand, error) {
	offset, err := parseNonNegativeIntQuery(r, "page_offset", "page.offset", 0)
	if err != nil {
		return domain.ListCustomersCommand{}, err
	}
	limit, err := parsePositiveIntQuery(r, "page_limit", "page.limit", 10)
	if err != nil {
		return domain.ListCustomersCommand{}, err
	}

	return domain.ListCustomersCommand{
		Filter: domain.CustomerFilter{
			ID:     queryValue(r, "filter_id", "filter.id"),
			Name:   queryValue(r, "filter_name", "filter.name"),
			Email:  queryValue(r, "filter_email", "filter.email"),
			Search: queryValue(r, "search"),
		},
		Offset:   offset,
		Limit:    limit,
		Includes: parseIncludes(queryValue(r, "include")),
	}, nil
}

func parseListAccountsRequest(r *http.Request) (domain.ListAccountsCommand, error) {
	offset, err := parseNonNegativeIntQuery(r, "page_offset", "page.offset", 0)
	if err != nil {
		return domain.ListAccountsCommand{}, err
	}
	limit, err := parsePositiveIntQuery(r, "page_limit", "page.limit", 10)
	if err != nil {
		return domain.ListAccountsCommand{}, err
	}

	return domain.ListAccountsCommand{
		Filter: domain.AccountDetailFilter{
			ID:       queryValue(r, "filter_id", "filter.id"),
			BankName: queryValue(r, "filter_bank_name", "filter.bankName"),
			Currency: queryValue(r, "filter_currency", "filter.currency"),
			Search:   queryValue(r, "search"),
		},
		Offset:   offset,
		Limit:    limit,
		Includes: parseIncludes(queryValue(r, "include")),
	}, nil
}

func parseCustomerSummaryRequest(r *http.Request) (domain.GetCustomerSummaryCommand, error) {
	customerID := queryValue(r, "customer_id", "id")
	if strings.TrimSpace(customerID) == "" {
		return domain.GetCustomerSummaryCommand{}, domain.NewValidationError(domain.ValidationDetail{
			Field:  "customer_id",
			Reason: "REQUIRED",
		})
	}

	return domain.GetCustomerSummaryCommand{CustomerID: customerID}, nil
}

func queryValue(r *http.Request, keys ...string) string {
	query := r.URL.Query()
	for _, key := range keys {
		if value := strings.TrimSpace(query.Get(key)); value != "" {
			return value
		}
	}
	return ""
}

func parseIncludes(value string) map[string]bool {
	includes := make(map[string]bool)
	for _, include := range strings.Split(value, ",") {
		include = strings.TrimSpace(include)
		if include != "" {
			includes[include] = true
		}
	}
	return includes
}

func parseNonNegativeIntQuery(r *http.Request, primaryKey string, legacyKey string, fallback int) (int, error) {
	return parseIntQuery(r, primaryKey, legacyKey, fallback, false)
}

func parsePositiveIntQuery(r *http.Request, primaryKey string, legacyKey string, fallback int) (int, error) {
	return parseIntQuery(r, primaryKey, legacyKey, fallback, true)
}

func parseIntQuery(r *http.Request, primaryKey string, legacyKey string, fallback int, positive bool) (int, error) {
	raw := queryValue(r, primaryKey, legacyKey)
	if raw == "" {
		return fallback, nil
	}

	value, err := strconv.Atoi(raw)
	if err != nil {
		return 0, &badRequestError{message: primaryKey + " must be an integer"}
	}
	if positive && value <= 0 {
		return 0, &badRequestError{message: primaryKey + " must be greater than zero"}
	}
	if !positive && value < 0 {
		return 0, &badRequestError{message: primaryKey + " must be zero or greater"}
	}

	return value, nil
}
