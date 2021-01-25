
package acceptance_tests

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

/*
	Tests support for external certificate lists. Test structure:

	1. Deploy HAProxy with internal certificate A
	2. Update external certificate list to add certificate B
	3. Verify that HTTPS requests using certificates A, B are working and C is not working
	4. Update external certificate list to remove B and add C
	5. Verify that HTTPS requests using certificates A, C are working and B is not working

*/

var _ = Describe("External Certificate Lists", func() {
	haproxyBackendPort := 12000

	It("Uses the correct certs", func() {
		opsfileSSLCertificate := `---
# Ensure HAProxy is in daemon mode (syslog server cannot be stdout)
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/syslog_server?
  value: "/var/vcap/sys/log/haproxy/syslog"
# Add CertA as a regular certificate
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?/-
  value:
    snifilter:
    - cert_a.haproxy.internal
    ssl_pem:
      cert_chain: ((cert_a.certificate))((cert_a.ca))
      private_key: ((cert_a.private_key))

# Configure external certificate list
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/ext_crt_list?
  value: true
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/ext_crt_list_file?
  value: ((ext_crt_list_path))
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/ext_crt_list_policy?
  value: continue

# Generate CA and certificates
- type: replace
  path: /variables?/-
  value:
    name: common_ca
    type: certificate
    options:
      is_ca: true
      common_name: bosh
- type: replace
  path: /variables?/-
  value:
    name: cert_a
    type: certificate
    options:
      ca: common_ca
      common_name: cert_a.haproxy.internal
      alternative_names: [cert_a.haproxy.internal]
- type: replace
  path: /variables?/-
  value:
    name: cert_b
    type: certificate
    options:
      ca: common_ca
      common_name: cert_b.haproxy.internal
      alternative_names: [cert_b.haproxy.internal]
- type: replace
  path: /variables?/-
  value:
    name: cert_c
    type: certificate
    options:
      ca: common_ca
      common_name: cert_c.haproxy.internal
      alternative_names: [cert_c.haproxy.internal]
`

		extCrtListPath := "/var/vcap/jobs/haproxy/config/ssl/ext-crt-list"
		haproxyInfo, varsStoreReader := deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileSSLCertificate}, map[string]interface{}{
			"ext_crt_list_path": extCrtListPath,
		}, true)

		var creds struct {
			CertA struct {
				Certificate string `yaml:"certificate"`
				CA          string `yaml:"ca"`
				PrivateKey  string `yaml:"private_key"`
			} `yaml:"cert_a"`
			CertB struct {
				Certificate string `yaml:"certificate"`
				CA          string `yaml:"ca"`
				PrivateKey  string `yaml:"private_key"`
			} `yaml:"cert_b"`
			CertC struct {
				Certificate string `yaml:"certificate"`
				CA          string `yaml:"ca"`
				PrivateKey  string `yaml:"private_key"`
			} `yaml:"cert_c"`
		}
		err := varsStoreReader(&creds)
		Expect(err).NotTo(HaveOccurred())

		// Wait for HAProxy to accept TCP connections
		waitForHAProxyListening(haproxyInfo)

		closeLocalServer, localPort := startDefaultTestServer()
		defer closeLocalServer()

		closeTunnel := setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)
		defer closeTunnel()

		client := buildHTTPClient(
			[]string{creds.CertA.CA, creds.CertB.CA, creds.CertC.CA},
			map[string]string{
				"cert_a.haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP),
				"cert_b.haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP),
				"cert_c.haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP),
			},
			[]tls.Certificate{}, "",
		)

		By("Sending a request to HAProxy using internal cert A works (default cert)")
		expectTestServer200(client.Get("https://cert_a.haproxy.internal:443"))

		By("Sending a request to HAProxy using external cert B fails (external cert not yet added)")
		_, err = client.Get("https://cert_b.haproxy.internal:443")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("certificate is valid for cert_a.haproxy.internal, not cert_b.haproxy.internal"))

		By("Sending a request to HAProxy using external cert C fails (external cert not yet added)")
		_, err = client.Get("https://cert_c.haproxy.internal:443")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("certificate is valid for cert_a.haproxy.internal, not cert_c.haproxy.internal"))

		// external certs format is a concatenated file containing certificate PEM, CA PEM, private key PEM
		pemChainCertB := bytes.NewBufferString(strings.Join([]string{creds.CertB.Certificate, creds.CertB.CA, creds.CertB.PrivateKey}, "\n"))
		pemChainCertBPath := "/var/vcap/jobs/haproxy/config/ssl/cert_b.haproxy.internal.pem"
		pemChainCertC := bytes.NewBufferString(strings.Join([]string{creds.CertC.Certificate, creds.CertC.CA, creds.CertC.PrivateKey}, "\n"))
		pemChainCertCPath := "/var/vcap/jobs/haproxy/config/ssl/cert_c.haproxy.internal.pem"

		extCrtList := bytes.NewBufferString(fmt.Sprintf("%s cert_b.haproxy.internal\n", pemChainCertBPath))

		By("Uploading external certificates and external cert list to HAProxy")
		uploadFile(haproxyInfo, pemChainCertB, pemChainCertBPath)
		defer deleteRemoteFile(haproxyInfo, pemChainCertBPath)
		uploadFile(haproxyInfo, extCrtList, extCrtListPath)
		defer deleteRemoteFile(haproxyInfo, extCrtListPath)

		By("Reloading HAProxy")
		reloadHAProxy(haproxyInfo)

		By("Waiting for HAProxy to start listening (up to two minutes)")
		waitForHAProxyListening(haproxyInfo)

		By("Sending a request to HAProxy using internal cert A works (default cert)")
		expectTestServer200(client.Get("https://cert_a.haproxy.internal:443"))

		By("Sending a request to HAProxy using external cert B works (external cert now added)")
		expectTestServer200(client.Get("https://cert_b.haproxy.internal:443"))

		By("Sending a request to HAProxy using external cert C fails (external cert not yet added)")
		_, err = client.Get("https://cert_c.haproxy.internal:443")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("certificate is valid for cert_a.haproxy.internal, not cert_c.haproxy.internal"))

		By("Removing external cert B and adding externat cert C to external cert list")
		extCrtList = bytes.NewBufferString(fmt.Sprintf("%s cert_c.haproxy.internal\n", pemChainCertCPath))

		deleteRemoteFile(haproxyInfo, pemChainCertBPath)
		uploadFile(haproxyInfo, pemChainCertC, pemChainCertCPath)
		defer deleteRemoteFile(haproxyInfo, pemChainCertCPath)
		uploadFile(haproxyInfo, extCrtList, extCrtListPath)

		By("Reloading HAProxy")
		reloadHAProxy(haproxyInfo)

		By("Waiting for HAProxy to start listening (up to two minutes)")
		waitForHAProxyListening(haproxyInfo)

		By("Sending a request to HAProxy using internal cert A works (default cert)")
		expectTestServer200(client.Get("https://cert_a.haproxy.internal:443"))

		By("Sending a request to HAProxy using external cert B fails (external cert that was removed)")
		_, err = client.Get("https://cert_b.haproxy.internal:443")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("certificate is valid for cert_a.haproxy.internal, not cert_b.haproxy.internal"))

		By("Sending a request to HAProxy using external cert C works (external cert that was added)")