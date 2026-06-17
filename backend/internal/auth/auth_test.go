package auth

import (
	"testing"
	"time"
)

func TestPasswordRoundTrip(t *testing.T) {
	h, err := HashPassword("hunter2pw")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(h, "hunter2pw") {
		t.Fatal("expected password to verify")
	}
	if CheckPassword(h, "wrong") {
		t.Fatal("expected wrong password to fail")
	}
}

func TestAccessTokenRoundTrip(t *testing.T) {
	tm := NewTokenManager("test-secret", time.Hour)
	tok, err := tm.NewAccessToken("user-123")
	if err != nil {
		t.Fatal(err)
	}
	sub, err := tm.ParseAccessToken(tok)
	if err != nil {
		t.Fatal(err)
	}
	if sub != "user-123" {
		t.Fatalf("got subject %q", sub)
	}
}

func TestRefreshTokenHashIsDeterministic(t *testing.T) {
	raw, hash, err := NewRefreshToken()
	if err != nil {
		t.Fatal(err)
	}
	if HashRefreshToken(raw) != hash {
		t.Fatal("hash of raw must equal returned hash")
	}
}
