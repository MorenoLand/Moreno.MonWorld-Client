package main

import "testing"

func TestVerifiedROMHashIsExplicit(t *testing.T) {
	if len(verifiedFireRedRev1SHA1) != 40 {
		t.Fatal("verified ROM hash must be a SHA-1 value")
	}
	if verifiedFireRedRev1SHA1 == "584dd9369b37ab3d3f44d4dd6af989e83f1a6013" {
		t.Fatal("patched fixture must not be accepted as the verified hash")
	}
}
