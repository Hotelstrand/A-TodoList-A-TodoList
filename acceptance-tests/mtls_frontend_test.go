package acceptance_tests

import (
	"crypto/tls"
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("mTLS", func() {
	var haproxyInfo haproxyInfo
	var closeTunnel func()
	var closeLocalServer func()

	haproxyBackendPort := 12000
	opsfileMTLS := `---
# Configure CA and cert chain
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?
  value:
  - snifilter:
    - a.haproxy.internal
    client_ca_file: ((client_a_ca.certificate))
    verify: optional
    ssl_pem:
      cert_chain: ((https_frontend.certificate))((https_frontend_ca.certificate))
      private_key: ((https_frontend.private_key))
  - snifilter:
    - b.haproxy.internal
    client_ca_file: ((client_b_ca.certificate))
    verify: required
    ssl_pem:
      cert_chain: ((https_frontend.certificate))((https_frontend_ca.certificate))
      private_key: ((https_frontend.private_key))
# Declare server certs
- type: replace
  path: /variables?/-
  value:
    name: https_frontend_ca
    type: certificate
    options:
      is_ca: true
      common_name: bosh
- type: replace
  path: /variables?/-
  value:
    name: https_frontend
    type: certificate
    options:
      ca: https_frontend_ca
      common_name: a.haproxy.internal
      alternative_names:
      - a.haproxy.internal
      - b.haproxy.internal
# De