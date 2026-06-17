package api

import "net/http"

func (s *Server) handlePurchaseStub(w http.ResponseWriter, r *http.Request) {
	writeError(w, 501, "not_implemented", "payment not available yet")
}
