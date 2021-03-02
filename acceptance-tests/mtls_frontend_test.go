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
   