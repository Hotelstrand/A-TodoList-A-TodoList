
package acceptance_tests

import (
	"crypto/tls"
	"fmt"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Backend match HTTP protocol", func() {
	var haproxyInfo haproxyInfo
	var closeTunnel func()
	var closeLocalServer func()
	var http1Client *http.Client
	var http2Client *http.Client

	haproxyBackendPort := 12000
	opsfileHTTPS := `---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/backend_ssl?
  value: verify
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/backend_ca_file?
  value: ((https_backend.ca))
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/backend_match_http_protocol?
  value: true
# Configure CA and cert chain
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?/-
  value:
    snifilter:
    - haproxy.internal
    ssl_pem:
      cert_chain: ((https_frontend.certificate))((default_ca.certificate))
      private_key: ((https_frontend.private_key))
    alpn: ['h2', 'http/1.1']
# Declare certs
- type: replace
  path: /variables?/-
  value:
    name: default_ca
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
      ca: default_ca
      common_name: haproxy.internal
      alternative_names: [haproxy.internal]
- type: replace
  path: /variables?/-
  value:
    name: https_backend
    type: certificate
    options:
      ca: default_ca
      common_name: 127.0.0.1
      alternative_names: [127.0.0.1]
`

	var creds struct {
		HTTPSFrontend struct {
			Certificate string `yaml:"certificate"`
			PrivateKey  string `yaml:"private_key"`
			CA          string `yaml:"ca"`
		} `yaml:"https_frontend"`
		HTTPSBackend struct {
			Certificate string `yaml:"certificate"`
			PrivateKey  string `yaml:"private_key"`
			CA          string `yaml:"ca"`
		} `yaml:"https_backend"`