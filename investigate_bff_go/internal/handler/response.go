package handler

type errorResponse struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code    string        `json:"code"`
	Message string        `json:"message"`
	ID      string        `json:"id"`
	Details []errorDetail `json:"details,omitempty"`
}

type errorDetail struct {
	Field  string         `json:"field"`
	Reason string         `json:"reason"`
	Meta   map[string]any `json:"meta,omitempty"`
}
