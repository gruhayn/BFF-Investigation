package enrichment

import (
	"sync"

	"investigate_bff/internal/model"
)

func RunPipeline[T any](items []T, enrichers []model.Enricher[T], includes map[string]bool) {
	var wg sync.WaitGroup

	for _, e := range enrichers {
		if includes[e.Key()] && e.DependsOn() == "" {
			wg.Add(1)
			go func(e model.Enricher[T]) {
				defer wg.Done()
				e.Enrich(items)
			}(e)
		}
	}
	wg.Wait()

	for _, e := range enrichers {
		dep := e.DependsOn()
		if includes[e.Key()] && dep != "" && includes[dep] {
			wg.Add(1)
			go func(e model.Enricher[T]) {
				defer wg.Done()
				e.Enrich(items)
			}(e)
		}
	}
	wg.Wait()
}
