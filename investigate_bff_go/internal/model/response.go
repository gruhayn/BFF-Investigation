package model

type PageInfo struct {
	TotalCount  int  `json:"totalCount"`
	Offset      int  `json:"offset"`
	Limit       int  `json:"limit"`
	HasNextPage bool `json:"hasNextPage"`
}

type PageResponse[T any] struct {
	Items    []T      `json:"items"`
	PageInfo PageInfo `json:"pageInfo"`
}
