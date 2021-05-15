package acceptance_tests

import (
	"fmt"
	"net/http"

	. "github.com/onsi/ginkgo/v2"
)

var _ = Describe("TCP Frontend", func() {
	It("Correctly proxies TCP requests", func() {
		opsfileTCP :