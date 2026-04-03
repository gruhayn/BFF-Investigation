package model

// /accounts endpoint - all models

type AccountDetail struct {
	ID            string         `json:"id"`
	AccountNumber string         `json:"accountNumber"`
	BankName      string         `json:"bankName"`
	Balance       float64        `json:"balance"`
	Currency      string         `json:"currency"`
	Holder        *AccountHolder `json:"holder,omitempty"`
	Transactions  []Transaction  `json:"transactions,omitempty"`
}

type AccountHolder struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type AccountDetailFilter struct {
	ID       string
	BankName string
	Currency string
	Search   string
}
