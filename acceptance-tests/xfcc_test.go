package acceptance_tests

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"math/big"
	"net/http"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type Certificate struct {
	CertPEM       string
	PrivateKeyPEM string
	X509Cert      *x509.Certificate
	PrivateKey    *rsa.PrivateKey
	TLSCert       tls.Certificate
}

/*
	https://bosh.io/jobs/haproxy?source=github.com/cloudfoundry-community/haproxy-boshrelease#p%3dha_proxy.forwarded_client_cert
	forwarded_client_cert
		always_forward_only 					=> X-Forwarded-Client-Cert is always forwarded

		forward_only 									=> X-Forwarded-Client-Cert is removed for non-mTLS connections
																	=> X-Forwarded-Client-Cert is forwarded for mTLS connections

		sanitize_set 									=> X-Forwarded-Client-Cert is removed for non-mTLS connections
																	=> X-Forwarded-Client-Cert is overwritten for mTLS connections

		forward_only_if_route_service => X-Forwarded-Client-Cert is removed for non-mTLS connections when X-Cf-Proxy-Signature header is not present
																		 X-Forwarded-Client-Cert is forwarded for non-mTLS connections when X-Cf-Proxy-Signature header is present
																		 X-Forwarded-Client-Cert is overwritten for mTLS connections
*/
var _ = Describe("forwarded_client_cert", func() {
	opsfileForwardedClientCert := `---
# Configure X-Forwarded-Client-Cert handling
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/forwarded_client_cert?
  value: ((forwarded_client_cert))
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/client_cert?
  value: true

# Configure CA and cert chain
- type: replace
  path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/crt_list?/-
  value:
    snifilter:
    - haproxy.internal
    ssl_pem:
      cert_chain: ((https_frontend.certificate))((https_frontend_ca.certificate))
      private_key: ((https_frontend.private_key))
    client_ca_file: ((client_ca_pem))

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
	var closeLocalServer func()
	var closeSSHTunnel context.CancelFunc
	var creds struct {
		HTTPSFrontend struct {
			Certificate string `yaml:"certificate"`
			PrivateKey  string `yaml:"private_key"`
			CA          string `yaml:"ca"`
		} `yaml:"https_frontend"`
		ClientCert struct {
			Certificate string `yaml:"certificate"`
			PrivateKey  string `yaml:"private_key"`
			CA          string `yaml:"ca"`
		} `yaml:"client_cert"`
	}
	var clientCert *Certificate
	var haproxyInfo haproxyInfo
	var deployVars map[string]interface{}
	var mtlsClient *http.Client
	var nonMTLSClient *http.Client
	var recordedHeaders http.Header
	var request *http.Request

	// These headers will be forwarded, overwritten or deleted
	// depending on the value of ha_proxy.forwarded_client_cert
	incomingRequestHeaders := map[string]string{
		"X-Forwarded-Client-Cert": "my-client-cert",
		"X-SSL-Client-Subject-Dn": "My App",
		"X-SSL-Client-Subject-Cn": "app.mycert.com",
		"X-SSL-Client-Issuer-Dn":  "ACME inc, USA",
		"X-SSL-Client-Issuer-Cn":  "mycert.com",
		"X-SSL-Client-Notbefore":  "Wednesday",
		"X-SSL-Client-Notafter":   "Thursday",
		"X-SSL-Client-Cert":       "ABC",
		"X-SSL-Client-Verify":     "DEF",
	}

	AfterEach(func() {
		if closeLocalServer != nil {
			defer closeLocalServer()
		}

		if closeSSHTunnel != nil {
			defer closeSSHTunnel()
		}
	})

	JustBeforeEach(func() {
		haproxyBackendPort := 12000
		var varsStoreReader varsStoreReader

		var err error
		var clientCA *Certificate
		clientCA, clientCert, err = generateClientCerts()
		Expect(err).NotTo(HaveOccurred())

		deployVars["client_ca_pem"] = clientCA.CertPEM

		haproxyInfo, varsStoreReader = deployHAProxy(baseManifestVars{
			haproxyBackendPort:    haproxyBackendPort,
			haproxyBackendServers: []string{"127.0.0.1"},
			deploymentName:        deploymentNameForTestNode(),
		}, []string{opsfileForwardedClientCert}, deployVars, true)

		err = varsStoreReader(&creds)
		Expect(err).NotTo(HaveOccurred())

		By("Starting a local http server to act as a backend")
		var localPort int
		closeLocalServer, localPort, err = startLocalHTTPServer(nil, func(w http.ResponseWriter, r *http.Request) {
			writeLog("Backend server handling incoming request")
			recordedHeaders = r.Header
			_, _ = w.Write([]byte("OK"))
		})
		Expect(err).NotTo(HaveOccurred())

		closeSSHTunnel = setupTunnelFromHaproxyToTestServer(haproxyInfo, haproxyBackendPort, localPort)

		nonMTLSClient = buildHTTPClient(
			[]string{creds.HTTPSFrontend.CA},
			map[string]string{"haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP)},
			[]tls.Certificate{}, "",
		)

		mtlsClient = buildHTTPClient(
			[]string{creds.HTTPSFrontend.CA},
			map[string]string{"haproxy.internal:443": fmt.Sprintf("%s:443", haproxyInfo.PublicIP)},
			[]tls.Certificate{clientCert.TLSCert}, "",
		)

		request, err = http.NewRequest("GET", "https://haproxy.internal:443", nil)
		Expect(err).NotTo(HaveOccurred())
		for key, value := range incomingRequestHeaders {
			request.Header.Set(key, value)
		}
	})

	Describe("When forwarded_client_cert is sanitize_set", func() {
		BeforeEach(func() {
			deployVars = map[string]interface{}{
				"forwarded_client_cert": "sanitize_set",
			}
		})

		It("Correctly handles the X-Forwarded-Client-Cert and related mTLS headers", func() {
			By("Correctly removes mTLS headers from non-mTLS requests")
			resp, err := nonMTLSClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			for key := range incomingRequestHeaders {
				Expect(recordedHeaders).NotTo(HaveKey(key))
			}

			By("Correctly replaces mTLS headers in mTLS requests")
			resp, err = mtlsClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))

			checkXFCCHeadersMatchCert(clientCert.X509Cert, recordedHeaders)
		})
	})

	Describe("When forwarded_client_cert is always_forward_only", func() {
		BeforeEach(func() {
			deployVars = map[string]interface{}{
				"forwarded_client_cert": "always_forward_only",
			}
		})

		It("Correctly handles the X-Forwarded-Client-Cert and related mTLS headers", func() {
			By("Correctly forwards mTLS headers from non-mTLS requests")
			resp, err := nonMTLSClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			for key, value := range incomingRequestHeaders {
				Expect(recordedHeaders.Get(key)).To(Equal(value))
			}

			By("Correctly forwards mTLS headers from mTLS requests")
			resp, err = mtlsClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))

			for key, value := range incomingRequestHeaders {
				Expect(recordedHeaders.Get(key)).To(Equal(value))
			}
		})
	})

	Describe("When forwarded_client_cert is forward_only", func() {
		BeforeEach(func() {
			deployVars = map[string]interface{}{
				"forwarded_client_cert": "forward_only",
			}
		})

		It("Correctly handles the X-Forwarded-Client-Cert and related mTLS headers", func() {
			By("Correctly removes mTLS headers from non-mTLS requests")
			resp, err := nonMTLSClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			for key := range incomingRequestHeaders {
				Expect(recordedHeaders).NotTo(HaveKey(key))
			}

			By("Correctly forwards mTLS headers from mTLS requests")
			resp, err = mtlsClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))

			for key, value := range incomingRequestHeaders {
				Expect(recordedHeaders.Get(key)).To(Equal(value))
			}
		})
	})

	Describe("When forwarded_client_cert is forward_only_if_route_service", func() {
		BeforeEach(func() {
			deployVars = map[string]interface{}{
				"forwarded_client_cert": "forward_only_if_route_service",
			}
		})

		It("Correctly handles the X-Forwarded-Client-Cert and related mTLS headers", func() {
			By("Correctly removes mTLS headers from non-mTLS requests")
			resp, err := nonMTLSClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			for key := range incomingRequestHeaders {
				Expect(recordedHeaders).NotTo(HaveKey(key))
			}

			By("Correctly forwards mTLS header from non-mTLS requests where X-Cf-Proxy-Signature is present")
			request.Header.Set("X-Cf-Proxy-Signature", "abc123")
			resp, err = nonMTLSClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))
			Expect(recordedHeaders.Get("X-Cf-Proxy-Signature")).To(Equal("abc123"))
			for key, value := range incomingRequestHeaders {
				Expect(recordedHeaders.Get(key)).To(Equal(value))
			}

			By("Correctly replaces mTLS headers in mTLS requests")
			resp, err = mtlsClient.Do(request)
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(http.StatusOK))

			checkXFCCHeadersMatchCert(clientCert.X509Cert, recordedHeaders)

			// X-Cf-Proxy-Signature should be left intact
			Expect(recordedHeaders.Get("X-Cf-Proxy-Signature")).To(Equal("abc123"))
		})
	})
})

func checkXFCCHeadersMatchCert(expectedCert *x509.Certificate, headers http.Header) {
	actualCert, err := x509.ParseCertificate([]byte(base64Decode(headers.Get("X-Forwarded-Client-Cert"))))
	Expect(err).NotTo(HaveOccurred())

	Expect(*actualCert).To(Equal(*expectedCert))

	Expect(base64Decode(headers.Get("X-SSL-Client-Subject-Dn"))).To(Equal("/C=Vatican City/O=Víkî's Vergnügungspark/CN=haproxy.client"))
	Expect(base64Decode(headers.Get("X-SSL-Client-Subject-CN"))).To(Equal("haproxy.client"))
	Expect(base64Decode(headers.Get("X-SSL-Client-Issuer-Dn"))).To(Equal("/C=Palau/O=Pete's Café"))
	Expect(headers.Get("X-SSL-Client-Notbefore")).To(Equal(expectedCert.NotBefore.UTC().Format("060102150405Z"))) //YYMMDDhhmmss[Z]
	Expect(headers.Get("X-SSL-Client-Notafter")).To(Equal(expectedCert.NotAfter.UTC().Format("060102150405Z")))   //YYMMDDhhmmss[Z]

	Expect(headers.