package main

import (
	"reflect"
	"testing"
)

// SSH sing-box (2026-10-30, lanjutan sshfix2): connect_timeout TIDAK
// diset (core tidak memutus dial jembatan di tengah jalan; batas waktu
// dipegang jembatan sendiri), client_version dikunci OpenSSH_7.8 (bukan
// acak), dan host_key_algorithms eksplisit modern-dulu + ssh-rsa terakhir
// (Dropbear 2019.78 hanya menandatangani RSA dengan ssh-rsa).
func TestSingboxSSHOutboundTimeoutAndVersion(t *testing.T) {
	sv := &Server{
		Proto: "ssh",
		Params: map[string]string{
			"server": "example.example", "username": "taptap", "password": "pw",
		},
	}
	ob, _ := serverToOutbound(sv, "Teskan")
	if ob == nil {
		t.Fatalf("outbound SSH hilang")
	}
	if ob["type"] != "ssh" {
		t.Fatalf("type = %v, mau ssh", ob["type"])
	}
	if _, ok := ob["connect_timeout"]; ok {
		t.Fatalf("connect_timeout tidak boleh diset: %v", ob["connect_timeout"])
	}
	if ob["client_version"] != "SSH-2.0-OpenSSH_7.8" {
		t.Fatalf("client_version = %v, mau SSH-2.0-OpenSSH_7.8", ob["client_version"])
	}
	want := []string{
		"ssh-ed25519",
		"ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521",
		"rsa-sha2-512", "rsa-sha2-256",
		"ssh-rsa",
	}
	got, ok := ob["host_key_algorithms"].([]string)
	if !ok || !reflect.DeepEqual(got, want) {
		t.Fatalf("host_key_algorithms = %v, mau %v", ob["host_key_algorithms"], want)
	}
	// KEX/cipher/mac sengaja TIDAK diset: negosiasi KEX sudah terbukti
	// sukses dengan irisan default (Dropbear 2019.78), jadi field itu
	// tidak boleh muncul sebagai tebakan.
	if _, ok := ob["kex_algorithm"]; ok {
		t.Fatalf("kex_algorithm tidak boleh diset tanpa bukti")
	}
	if _, ok := ob["cipher"]; ok {
		t.Fatalf("cipher tidak boleh diset tanpa bukti")
	}
	if _, ok := ob["mac"]; ok {
		t.Fatalf("mac tidak boleh diset tanpa bukti")
	}
}
