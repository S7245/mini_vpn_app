package api

import (
	"net/http"
	"os"
)

// scalarHTML embeds the Scalar API Reference, which loads the spec from
// /openapi.yaml (same origin) and supports Authorize + Try-it-out.
const scalarHTML = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>mini_vpn backend — API Reference</title>
  </head>
  <body>
    <script id="api-reference" data-url="/openapi.yaml"></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>`

func (s *Server) handleDocs(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(scalarHTML))
}

func (s *Server) handleOpenAPISpec(w http.ResponseWriter, r *http.Request) {
	b, err := os.ReadFile(s.cfg.OpenAPISpecPath)
	if err != nil {
		writeError(w, 500, "internal", "openapi spec unavailable")
		return
	}
	w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
	_, _ = w.Write(b)
}
