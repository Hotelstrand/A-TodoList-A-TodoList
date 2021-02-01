package acceptance_tests

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Lua scripting", func() {
	It("Deploys haproxy with lua script", func() {
		opsfileLua := `---
# Enable Lua scripting
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/lua_scripts?/-
  value: "/var/vcap/packages/haproxy/lua_test.lua"
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/frontend_config?
  value: "http-request use-service lua.lua_test if { path /lua_test }"
`

		replyLuaCo