package client

import (
	"investigate_bff/internal/model"
)

// Hashmap indexes (built in init.go)
var acctToCustomerIndex map[string]string
var holderByCustomerID map[string]model.AccountHolder

type holderClient struct{}

func NewHolderClient() *holderClient { return &holderClient{} }

var dummyHolder = model.AccountHolder{ID: "c1", Name: "John Doe", Email: "john.doe@example.com"}

func (c *holderClient) GetByAccountIDs(ids []string) (map[string]model.AccountHolder, error) {
	if len(ids) == 0 {
		return map[string]model.AccountHolder{}, nil
	}
	result := map[string]model.AccountHolder{ids[0]: dummyHolder}
	return result, nil
}
