package core

import (
	"errors"

	"github.com/InazumaV/V2bX/conf"
)

var (
	cores = map[string]func(c *conf.CoreConfig) (Core, error){}
)

func NewCore(c []conf.CoreConfig) (Core, error) {
	if len(c) == 0 {
		// Default to available dual cores (xray + sing)
		defaultCores := []conf.CoreConfig{
			{Type: "xray"},
		}
		if _, ok := cores["sing"]; ok {
			defaultCores = append(defaultCores, conf.CoreConfig{Type: "sing"})
		}
		c = defaultCores
	}
	// multi core
	if len(c) > 1 {
		return NewSelector(c)
	}
	// one core
	if f, ok := cores[c[0].Type]; ok {
		return f(&c[0])
	} else {
		return nil, errors.New("unknown core type")
	}
}

func RegisterCore(t string, f func(c *conf.CoreConfig) (Core, error)) {
	cores[t] = f
}

func RegisteredCore() []string {
	cs := make([]string, 0, len(cores))
	for k := range cores {
		cs = append(cs, k)
	}
	return cs
}
