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
  value: ((deployment-name))
`

var opsfileChangeVersion string = `---
# Deploy dev version we just compiled
- type: replace
  path: /releases/name=haproxy
  value:
    name: haproxy
    version: ((release-version))
`

var opsfileAddSSHUser string = `---
# Install OS conf so that we can SSH into VM to inspect configuration
- type: replace
  path: /releases/-
  value:
    name: os-conf
    version: latest

# Add an SSH user
- type: replace
  path: /instance_groups/name=haproxy/jobs/-
  value:
    name: user_add
    release: os-conf
    properties:
      users:
      - name: ((ssh_user))
        public_key: ((ssh_key.public_key))
        sudo: true

# Generate an SSH key-pair
- type: replace
  path: /variables?/-
  value:
    name: ssh_key
    type: ssh
`

// opsfiles that need to be set for all tests
var defaultOpsfiles = []string{opsfileChangeName, opsfileChangeVersion, opsfileAddSSHUser}
var defaultSSHUser string = "ginkgo"

func buildManifestVars(baseManifestVars baseManifestVars, customVars map[string]interface{}) map[string]interface{} {
	vars := map[string]interface{}{
		"release-version":         config.ReleaseVersion,
		"haproxy-backend-port":    fmt.Sprintf("%d", baseManifestVars.haproxyBackendPort),
		"haproxy-backend-servers": baseManifestVars.haproxyBackendServers,
		"deploym