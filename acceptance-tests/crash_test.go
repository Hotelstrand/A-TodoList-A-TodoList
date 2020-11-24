package acceptance_tests

import (
	"fmt"
	"net"
	"net/http"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Crash Test", func() {
	opsfileDrainTimeout := `---
# Enable health check
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/enable_health_check_http?
  value: true
# Enable draining
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/drain_enable?
  value: true
# Set grace period to 1s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/drain_frontend_grace_time?
  value: 1
# Set drain period to 1s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/drain_timeout?
  value: 1
`
	It("Restarts if terminated by a crash", func() {
		haproxyBackendPort := 12000
		// Expect initial deployment to be failing due to lack of healthy backends
		haproxyInfo, _ := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendS