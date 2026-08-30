package router

import (
	"net/http"
	"strings"
)

type HandlerFunc func(http.ResponseWriter, *http.Request, map[string]string)
type route struct {
	method string
	parts  []string
	h      HandlerFunc
}
type Router struct{ routes []route }

func New() *Router { return &Router{} }
func (x *Router) Handle(method, path string, h HandlerFunc) {
	x.routes = append(x.routes, route{method: method, parts: split(path), h: h})
}
func (x *Router) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	for _, rt := range x.routes {
		if rt.method != r.Method {
			continue
		}
		parts := split(r.URL.Path)
		if len(parts) != len(rt.parts) {
			continue
		}
		params := map[string]string{}
		ok := true
		for i, p := range rt.parts {
			if strings.HasPrefix(p, "{") && strings.HasSuffix(p, "}") {
				params[p[1:len(p)-1]] = parts[i]
			} else if p != parts[i] {
				ok = false
				break
			}
		}
		if ok {
			rt.h(w, r, params)
			return
		}
	}
	http.NotFound(w, r)
}
func split(p string) []string {
	p = strings.Trim(p, "/")
	if p == "" {
		return nil
	}
	return strings.Split(p, "/")
}
