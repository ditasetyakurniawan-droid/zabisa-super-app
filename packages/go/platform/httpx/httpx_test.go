package httpx

import "testing"

func TestNewIDIsUUIDLikeAndUnique(t *testing.T) {
	a, b := NewID(), NewID()
	if a == b {
		t.Fatal("ids must be unique")
	}
	if len(a) != 36 {
		t.Fatalf("expected 36 chars, got %d", len(a))
	}
}
