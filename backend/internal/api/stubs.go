package api

import "net/http"

func (s *Server) handleGetSubscription(w http.ResponseWriter, r *http.Request) { writeError(w, 501, "todo", "subscription") }
func (s *Server) handleListDevices(w http.ResponseWriter, r *http.Request)      { writeError(w, 501, "todo", "devices") }
func (s *Server) handleRegisterDevice(w http.ResponseWriter, r *http.Request)   { writeError(w, 501, "todo", "devices") }
func (s *Server) handleRevokeDevice(w http.ResponseWriter, r *http.Request)     { writeError(w, 501, "todo", "devices") }
func (s *Server) handleListNodes(w http.ResponseWriter, r *http.Request)        { writeError(w, 501, "todo", "nodes") }
func (s *Server) handleSelectBest(w http.ResponseWriter, r *http.Request)       { writeError(w, 501, "todo", "nodes") }
func (s *Server) handlePurchaseStub(w http.ResponseWriter, r *http.Request) {
	writeError(w, 501, "not_implemented", "payment not available yet")
}
