package domain

import "errors"

var ErrCustomerNotFound = errors.New("customer not found")

type ValidationDetail struct {
	Field  string         `json:"field"`
	Reason string         `json:"reason"`
	Meta   map[string]any `json:"meta,omitempty"`
}

type ValidationError struct {
	Details []ValidationDetail
}

func NewValidationError(details ...ValidationDetail) error {
	return &ValidationError{Details: details}
}

func (e *ValidationError) Error() string {
	return "validation failed"
}

func AsValidationError(err error) (*ValidationError, bool) {
	var validationErr *ValidationError
	if errors.As(err, &validationErr) {
		return validationErr, true
	}
	return nil, false
}
