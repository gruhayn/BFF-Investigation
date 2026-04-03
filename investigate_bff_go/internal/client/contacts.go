package client

import (
	"investigate_bff/internal/model"
)

var contactStore = []model.Contact{
	{ID: "con1", CustomerID: "c1", Phone: "+1-555-0101", Type: "mobile"},
	{ID: "con2", CustomerID: "c1", Phone: "+1-555-0102", Type: "work"},
	{ID: "con3", CustomerID: "c2", Phone: "+44-20-1234", Type: "home"},
	{ID: "con4", CustomerID: "c2", Phone: "+44-20-5678", Type: "mobile"},
	{ID: "con5", CustomerID: "c3", Phone: "+49-30-9876", Type: "work"},
	{ID: "con6", CustomerID: "c4", Phone: "+33-1-4321", Type: "mobile"},
	{ID: "con7", CustomerID: "c5", Phone: "+81-3-5555", Type: "home"},
	{ID: "con8", CustomerID: "c5", Phone: "+81-3-6666", Type: "work"},
}

// Hashmap index: customerID → []Contact (built in init.go)
var contactsByCustomerID map[string][]model.Contact

type contactClient struct{}

func NewContactClient() *contactClient { return &contactClient{} }

var dummyContact = model.Contact{ID: "con1", CustomerID: "c1", Phone: "+1-555-0101", Type: "mobile"}

func (c *contactClient) GetByCustomerIDs(ids []string) (map[string][]model.Contact, error) {
	result := map[string][]model.Contact{ids[0]: {dummyContact}}
	return result, nil
}
