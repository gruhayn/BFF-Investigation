package handler

import (
	"errors"
	"net/http"

	"investigate_bff/internal/domain"
)

func mapErrorInfo(err error) (int, string, string) {
	switch {
	case errors.Is(err, domain.ErrCustomerNotFound):
		return http.StatusNotFound, "INVESTIGATE_BFF.NOT_FOUND.CUSTOMER_NOT_FOUND", "Customer not found."
	default:
		return http.StatusInternalServerError, "INVESTIGATE_BFF.SERVER.INTERNAL_ERROR", "Internal server error."
	}
}
