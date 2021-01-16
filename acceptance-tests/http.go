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
		server.S