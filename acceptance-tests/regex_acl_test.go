package acceptance_tests

import (
	"fmt"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Regex-based ACLs", func() {
	It("Works", func() {
		opsfileRegexACLs := `---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/frontend_config?
  value: |-
    acl is_regex_match url,debug -i -m reg foo
    http-request deny deny_status 429 if is_regex_match
    http-request deny deny_status 401 if ! is_regex_match
`
		haproxyBackendPort := 12000
		haproxyInfo, _ := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileRegexACLs}, map[string]interface{}{}