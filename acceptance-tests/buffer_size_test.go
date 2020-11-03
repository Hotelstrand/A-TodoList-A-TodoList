package acceptance_tests

import (
	"fmt"
	"math/rand"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("max_rewrite and buffer_size_bytes", func() {
	It("Allows HTTP requests as large as buffer_size_bytes - max_rewrite", func() {
		opsfileBufferSize := `---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/max_rewrite?
  value: 4096
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/buffer_size_bytes?
  value: 71000
`
		haproxyBackendPort := 12000
		haproxyInfo, _ := deployHAProxy(baseManifestV