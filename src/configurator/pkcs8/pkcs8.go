package pkcs8

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/asn1"
)

// Until we bump to go 1.10, from https://stackoverflow.com/a/40510456
type pkcs8Key struct {
	Version             int
	PrivateKeyAlgorithm []asn1.ObjectIdentifier
	PrivateKey          []byte
}

func MarshalPKCS8PrivateKey(key *rsa.PrivateKey) ([]byte, error) {
	var pkey pkcs8Key
	pkey.Version = 0
	pkey.PrivateKeyAlgorithm = make([]asn1.ObjectIdentifier, 1)
	pkey.PrivateKeyAlgorithm[0] = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 1, 1}
	pkey.PrivateKey = x509.MarshalPKCS1PrivateKey(key)

	return asn1.Marshal(pkey)
}
