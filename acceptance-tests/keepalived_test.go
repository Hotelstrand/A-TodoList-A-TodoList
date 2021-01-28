package acceptance_tests

import (
	"fmt"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
)

var _ = Describe("keepalived", func() {
	It("Deploys haproxy with keepalived", func() {
		opsfileKeepalived := `---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=keepalived?/release?
  value: haproxy
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=keepalived?/properties/keepalived/vip?
  value: 10.245.0.99
`
		keepalivedVIP := "10.245.0.9