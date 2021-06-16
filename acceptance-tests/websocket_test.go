package acceptance_tests

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
)

var _ = Describe("HTTPS Frontend", func() {
	var haproxyInfo haproxyInfo
	var closeTunnel func()
	var closeLocalServer func()
	var enableHTTP2 bool
	var disableBackendHttp2Websockets bool
	var http1Client *http.Client
	var http2Client *http.Client

	haproxyBackendPort := 12000
	opsfileHTTPS := `---
# Configure HTTP2
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/enable_http2?
  value: ((enable_http2))
# Configure Disabling Backend HTTP2 Websockets
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/disable_backend_http2_websockets?
  value: ((disable_backend_http2_websockets))
# Configure CA and cert chain
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?/-
  value:
    snifilter:
    - haproxy.internal
    ssl_pem:
      cert_chain: ((https_frontend.certificate))((https_frontend_ca.certificate))
      private_key: ((https_frontend.private_key))
# Declare certs
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
      common_name: haproxy.internal
      alternative_names: [haproxy.internal]
`

	var creds struct {
		HTTPSFrontend struct {
			Certificate string `yaml:"certificate"`
			PrivateKey  string `yaml:"private_key"`
			CA          string `yaml:"ca"`
		} `yaml:"https_frontend"`
	}

	JustBeforeEach(func() {
		var varsStoreReader varsStoreReader
		haproxyInfo, varsStoreReader = deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileHTTPS}, map[string]interface{}{
			"enable_http2":                     enableHTTP2,
			"disable_backend_http2_websockets": disableBackendHttp2Websockets,
		}, true)

		err := varsStoreReader(&creds)
		Expect(err).NotTo(HaveOccurred())

		var localPort int
		closeLocalServer, localPort = startDefaultTestServer()
		closeTunnel = setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)

		http1Client = buildHTTPClient(
			[]string{creds.HTTPSFrontend.CA},
			map[string]string{"haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP)},
			[]tls.Certificate{}, "",
		)

		http2Client = buildHTTP2Client(
			[]string{creds.HTTPSFrontend.CA},
			map[string]string{"haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP)},
			[]tls.Certificate{},
		)
	})

	AfterEach(func() {
		if closeLocalServer != nil {
			defer closeLocalServer()
		}
		if closeTunnel != nil {
			defer closeTunnel()
		}
	})

	Context("When ha_proxy.disable_backend_http2_websockets is true", func() {
		BeforeEach(func() {
			enableHTTP2 = true
			disableBackendHttp2Websockets = true
		})

		It("succeeds with a websocket", func() {
			dialer := websocket.DefaultDialer
			dialer.TLSClientConfig = buildTLSConfig([]string{creds.HTTPSFrontend.CA}, []tls.Certificate{}, "")
			dialer.NetDialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
				if addr == "haproxy.internal:443" {
					addr = fmt.Sprintf("%s:443", haproxyInfo.PublicIP)
				}

				return (&net.Dialer{
					Timeout:   30 * time.Second,
					KeepAlive: 30 * time.Second,
				}).DialContext(ctx, network, addr)
			}

			By("Sending a request to HAProxy using HTTP 1.1")
			resp, err := http1Client.Get("https://haproxy.internal:443")
			Expect(err).NotTo(HaveOccurred())

			Expect(resp.ProtoMajor).To(Equal(1))

			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			Eventually(gbytes.BufferReader(resp.Body)).Should(gbytes.Say("Hello cloud foundry"))

			By("Sending a request to HAProxy using HTTP 2")
			resp, err = http2Client.Get("https://haproxy.internal:443")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ProtoMajor).To(Equal(2))

			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			Eventually(gbytes.BufferReader(resp.Body)).Should(gbytes.Say("Hello cloud foundry"))

			By("Sending a request using websockets")
			websocketConn, _, err := dialer.Dial("wss://haproxy.internal:443", nil)
			Expect(err).NotTo(HaveOccurred())
			defer websocketConn.Close()

			err = websocketCon