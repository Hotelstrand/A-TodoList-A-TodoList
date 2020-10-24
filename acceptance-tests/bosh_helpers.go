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
		"deployment-name":         baseManifestVars.deploymentName,
		"ssh_user":                defaultSSHUser,
	}
	for k, v := range customVars {
		vars[k] = v
	}

	return vars
}

func buildHAProxyInfo(baseManifestVars baseManifestVars, varsStoreReader varsStoreReader) haproxyInfo {
	var creds struct {
		SSHKey struct {
			PrivateKey           string `yaml:"private_key"`
			PublicKey            string `yaml:"public_key"`
			PublicKeyFingerprint string `yaml:"public_key_fingerprint"`
		} `yaml:"ssh_key"`
	}
	err := varsStoreReader(&creds)
	Expect(err).NotTo(HaveOccurred())

	Expect(creds.SSHKey.PrivateKey).NotTo(BeEmpty())
	Expect(creds.SSHKey.PublicKey).NotTo(BeEmpty())

	By("Fetching the HAProxy public IP")
	instances := boshInstances(baseManifestVars.deploymentName)
	haproxyPublicIP := instances[0].ParseIPs()[0]
	Expect(haproxyPublicIP).ToNot(BeEmpty())

	return haproxyInfo{
		PublicIP:                haproxyPublicIP,
		SSHPrivateKey:           creds.SSHKey.PrivateKey,
		SSHPublicKey:            creds.SSHKey.PublicKey,
		SSHPublicKeyFingerprint: creds.SSHKey.PublicKeyFingerprint,
		SSHUser:                 defaultSSHUser,
	}
}

// Helper method for deploying HAProxy
// Takes the HAProxy base manifest vars, an array of custom opsfiles, and a map of custom vars
// Returns 'info' struct containing public IP and ssh creds, and a callback to deserialize properties from the vars store
// Use expectSuccess with false if the base configuration will not start successfully, e.g. because
// files that are referenced in the configuration still need to be uploaded, or a custom backend needs more time to start up.
// In those cases, `monit` will keep restarting the boshrelease and the test can expect the procesess to be healthy after
// the necessary referenced resources are available.
func deployHAProxy(baseManifestVars baseManifestVars, customOpsfiles []string, customVars map[string]interface{}, expectSuccess bool) (haproxyInfo, varsStoreReader) {
	manifestVars := buildManifestVars(baseManifestVars, customVars)
	opsfiles := append(defaultOpsfiles, customOpsfiles...)
	cmd, varsStoreReader := deployBaseManifestCmd(baseManifestVars.deploymentName, opsfiles, manifestVars)

	dumpCmd(cmd)
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())

	if expectSuccess {
		Eventually(session, 20*time.Minute, time.Second).Should(gexec.Exit(0))
	} else {
		Eventually(session, 20*time.Minute, time.Second).Should(gexec.Exit())
		Expect(session.ExitCode()).NotTo(BeZero())
	}

	haproxyInfo := buildHAProxyInfo(baseManifestVars, varsStoreReader)

	// Dump HAProxy config to help debugging
	dumpHAProxyConfig(haproxyInfo)

	return haproxyInfo, varsStoreReader
}

func dumpCmd(cmd *exec.Cmd) {
	writeLog("---------- Command to run ----------")
	writeLog(cmd.String())
	writeLog("------------------------------------")
}

func dumpHAProxyConfig(haproxyInfo haproxyInfo) {
	By("Checking /var/vcap/jobs/haproxy/config/haproxy.config")
	haProxyConfig, _, err := runOnRemote(haproxyInfo.SSHUser, haproxyInfo.PublicIP, haproxyInfo.SSHPrivateKey, "cat /var/vcap/jobs/haproxy/config/haproxy.config")
	Expect(err).NotTo(HaveOccurred())
	writeLog("---------- HAProxy Config ----------")
	writeLog(haProxyConfig)
	writeLog("------------------------------------")
}

// Takes bosh deployment name, ops files and vars.
// Returns a cmd object and a callback to deserialise the bosh-generated vars store after cmd has executed
func deployBaseManifestCmd(boshDeployment string, opsFilesContents []string, vars map[string]interface{}) (*exec.Cmd, varsStoreReader) {
	By(fmt.Sprintf("Deploying HAProxy (deployment name: %s)", boshDeployment))
	args := []string{"deploy"}

	// ops files
	for _, opsFileContents := range opsFilesContents {
		opsFile, err := ioutil.TempFile("", "haproxy-tests-ops-file-*.yml")
		Expect(err).NotTo(HaveOccurred())

		writeLog(fmt.Sprintf("Wri