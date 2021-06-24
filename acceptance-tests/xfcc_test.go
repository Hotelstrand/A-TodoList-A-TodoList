package acceptance_tests

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"math/big"
	"net/http"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type Certificate struct {
	CertPEM       string
	PrivateKeyPEM string
	X509Cert      *x509.Certificate
	PrivateKey    *rsa.PrivateKey
	TLSCert       tls.Certificate
}

/*
	https://bosh.io/jobs/haproxy?source=github.com/cloudfoundry-community/haproxy-boshrelease#p%3dha_proxy.forwarded_client_cert
	forwarded_client_cert
		always_forward_only 					=> X-Forwarded-Client-Cert is always forwarded

		forward_only 									=> X-Forwarded-Client-Cert is removed for non-mTLS connections
																	=> X-Forwarded-Client-Cert is forwarded for mTLS connections

		sanitize_set 									=> X-Forwarded-Client-Cert is removed for non-mTLS connections
																	=> X-Forwarded-Client-Cert is overwritten for mTLS connections

		forward_only_if_route_service => X-Forwarded-Client-Cert is removed for non-mTLS connections when X-Cf-Proxy-Signature header is not present
																		 X-Forwarded-Client-Cert is forwarded for non-mTLS connections when X-Cf-Proxy-Signature header is present
																		 X-Forwarded-Client-Cert is overwritten for mTLS connections
*/
var _ = Describe("forwarded_client_cert", func() {
	opsfileForwardedClientCert := `---
# Configure X-Forwarded-Client-Cert handling
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/forwarded_client_cert?
  value: ((forwarded_client_cert))
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/client_cert?
  value: true

# Configure CA and cert chain
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?/-
  value:
    snifilter: