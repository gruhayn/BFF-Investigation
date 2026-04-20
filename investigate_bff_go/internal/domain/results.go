package domain

type PageInfo struct {
	TotalCount int  `json:"total_count"`
	Offset     int  `json:"offset"`
	Limit      int  `json:"limit"`
	HasMore    bool `json:"has_more"`
}

type PageResult[T any] struct {
	Items      []T      `json:"items"`
	NextCursor string   `json:"next_cursor,omitempty"`
	HasMore    bool     `json:"has_more"`
	PageInfo   PageInfo `json:"page_info"`
}
