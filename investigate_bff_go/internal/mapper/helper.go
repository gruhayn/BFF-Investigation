package mapper

import "investigate_bff/internal/model"

func Paginate[T any](items []T, offset, limit int) ([]T, model.PageInfo) {
	if items == nil {
		items = []T{}
	}
	total := len(items)
	if offset > total {
		offset = total
	}
	end := offset + limit
	if end > total {
		end = total
	}
	return items[offset:end], model.PageInfo{
		TotalCount:  total,
		Offset:      offset,
		Limit:       limit,
		HasNextPage: end < total,
	}
}

func ToPageResponse[T any](items []T, offset, limit int) model.PageResponse[T] {
	paged, info := Paginate(items, offset, limit)
	return model.PageResponse[T]{Items: paged, PageInfo: info}
}
