package acceptance_tests

import (
	"fmt"
	"net"
	"net/http"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Crash Test", func() {
	opsfileDrainTimeout := `---
# Enable