package service

type asyncResult[T any] struct {
	value T
	err   error
}

func async[T any](fn func() (T, error)) <-chan asyncResult[T] {
	resultCh := make(chan asyncResult[T], 1)
	go func() {
		value, err := fn()
		resultCh <- asyncResult[T]{value: value, err: err}
	}()
	return resultCh
}
