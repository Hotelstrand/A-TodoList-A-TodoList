package acceptance_tests

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("HTTP Health Check", func() {
	opsfileHTTPHealthcheck := `---
# Enable health check
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/enable_health_check_http?
  value: true
`

	It("Correctly fails to start if there is no healthy backend", func(