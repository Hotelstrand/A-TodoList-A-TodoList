
package acceptance_tests

import (
	"fmt"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Rate-Limiting", func() {
	It("Connections/Requests aren't blocked when block config isn't set", func() {
		rateLimit := 5
		opsfileConnectionsRateLimit := fmt.Sprintf(`---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit?/requests
  value: %d
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit/window_size?
  value: 10s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit/table_size?
  value: 100
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit?/connections
  value: %d
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit/window_size?
  value: 100s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit/table_size?
  value: 100
`, rateLimit, rateLimit)
		haproxyBackendPort := 12000
		haproxyInfo, _ := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileConnectionsRateLimit}, map[string]interface{}{}, true)

		closeLocalServer, localPort := startDefaultTestServer()
		defer closeLocalServer()

		closeTunnel := setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)
		defer closeTunnel()

		By("Sending requests to test app, expecting none to be blocked")
		testRequestCount := int(float64(rateLimit) * 1.5)
		for i := 0; i < testRequestCount; i++ {
			rt := &http.Transport{
				DisableKeepAlives: true,
			}
			client := &http.Client{Transport: rt}
			resp, err := client.Get(fmt.Sprintf("http://%s/foo", haproxyInfo.PublicIP))
			// sucessful requests
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
		}
	})

	It("Request Based Limiting Works", func() {
		requestLimit := 5
		opsfileRequestRateLimit := fmt.Sprintf(`---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit?/requests
  value: %d
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit/window_size?
  value: 10s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit/table_size?
  value: 100
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/requests_rate_limit/block?
  value: true
`, requestLimit)

		haproxyBackendPort := 12000
		haproxyInfo, _ := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileRequestRateLimit}, map[string]interface{}{}, true)

		closeLocalServer, localPort := startDefaultTestServer()
		defer closeLocalServer()

		closeTunnel := setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)
		defer closeTunnel()

		testRequestCount := int(float64(requestLimit) * 1.5)
		firstFailure := -1
		successfulRequestCount := 0
		for i := 0; i < testRequestCount; i++ {
			resp, err := http.Get(fmt.Sprintf("http://%s/foo", haproxyInfo.PublicIP))
			Expect(err).NotTo(HaveOccurred())
			switch resp.StatusCode {
			case http.StatusOK:
				successfulRequestCount++
			case http.StatusTooManyRequests:
				if firstFailure == -1 {
					firstFailure = i
				}
			}
		}

		By("The first request should fail after we've sent the amount of requests specified in the Request Rate Limit")
		Expect(firstFailure).To(Equal(requestLimit))
		By("The total amount of successful requests per time window should equal the Request Rate Limit")
		Expect(successfulRequestCount).To(Equal(requestLimit))
	})

	It("Connection Based Limiting Works", func() {
		connLimit := 5
		opsfileConnectionsRateLimit := fmt.Sprintf(`---
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit?/connections
  value: %d
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit/window_size?
  value: 100s
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit/table_size?
  value: 100
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/connections_rate_limit/block?
  value: true
`, connLimit)
		haproxyBackendPort := 12000
		haproxyInfo, _ := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileConnectionsRateLimit}, map[string]interface{}{}, true)

		closeLocalServer, localPort := startDefaultTestServer()
		defer closeLocalServer()

		closeTunnel := setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)