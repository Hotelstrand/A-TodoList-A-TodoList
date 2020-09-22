package acceptance_tests

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os/exec"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"gopkg.in/yaml.v2"
)

type haproxyInfo struct {
	SSHPrivateKey           string
	SSHPublicKey            string
	SSHPublicKeyFingerprint string
	SSHUser                 string
	PublicIP                string
}

type baseManifestVars struct {
	haproxyBackendPort    int
	haproxyBackendServers []string
	deploymentName        string
}

type varsStoreReader func(interface{}) error

var opsfileChangeName string = `---
# change deployment name to allow multiple simultaneous deployments
- type: replace
  path: /name
  valu