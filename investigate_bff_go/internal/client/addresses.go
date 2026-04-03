package client

import (
	"investigate_bff/internal/model"
)

var addressStore = []model.Address{
	{ID: "addr1", CustomerID: "c1", Street: "123 Main St", City: "New York", Country: "USA", ZipCode: "10001"},
	{ID: "addr2", CustomerID: "c1", Street: "456 Park Ave", City: "New York", Country: "USA", ZipCode: "10002"},
	{ID: "addr3", CustomerID: "c2", Street: "789 Oak Rd", City: "London", Country: "UK", ZipCode: "SW1A 1AA"},
	{ID: "addr4", CustomerID: "c3", Street: "321 Pine St", City: "Berlin", Country: "Germany", ZipCode: "10115"},
	{ID: "addr5", CustomerID: "c4", Street: "654 Elm Blvd", City: "Paris", Country: "France", ZipCode: "75001"},
	{ID: "addr6", CustomerID: "c4", Street: "987 Cedar Ln", City: "Lyon", Country: "France", ZipCode: "69001"},
	{ID: "addr7", CustomerID: "c5", Street: "111 Maple Dr", City: "Tokyo", Country: "Japan", ZipCode: "100-0001"},
}

// Hashmap index: customerID → []Address (built in init.go)
var addressesByCustomerID map[string][]model.Address

type addressClient struct{}

func NewAddressClient() *addressClient { return &addressClient{} }

var dummyAddress = model.Address{ID: "addr1", CustomerID: "c1", Street: "123 Main St", City: "New York", Country: "USA", ZipCode: "10001"}

func (c *addressClient) GetByCustomerIDs(ids []string) (map[string][]model.Address, error) {
	result := map[string][]model.Address{ids[0]: {dummyAddress}}
	return result, nil
}
