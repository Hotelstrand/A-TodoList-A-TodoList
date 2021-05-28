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
  path: 