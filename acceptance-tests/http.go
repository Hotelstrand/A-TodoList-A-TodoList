package acceptance_tests

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"time"

	"golang.org/x/net/http2"
)

// starts a local http server handling the provided handler
// returns a close function to stop the server and the port the server is listening on
func startLocalHTTPServer(tlsConfig *tls.Config, handler func(http.ResponseWriter, *http.Request)) (func(), int, error) {
	server := httptest.NewUnstartedServer(http.HandlerFunc(handler))
	if tlsConfig != nil {
		server.TLS = tlsConfig
		server.StartTLS()
	} else {
		server.Start()
	}

	serverURL, err := url.Parse(server.URL)
	if err != nil {
		return nil, 0, err
	}

	port, err := strconv.ParseInt(serverURL.Port(), 10, 64)
	if err != nil {
		return nil, 0, err
	}

	return server.Close, int(port), nil
}

// Build an HTTP client with custom CA certificate pool which resolves hosts based on provided map
func buildHTTPClient(caCerts []string, addressMap map[string]string