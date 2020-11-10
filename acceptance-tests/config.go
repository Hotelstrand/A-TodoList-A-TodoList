package acceptance_tests

import (
	"fmt"
	"os"
	"os/exec"
)

var config Config

type Config struct {
	ReleaseRepoPath  string `json:"releaseRepoPath"`
	ReleaseVersion   string `json:"releaseVersion"`
	BoshCACert       string `json:"boshCACert"`
	BoshClient       string `json:"boshClient"`
	BoshClientSecret string `json:"boshClientSecret"`
	BoshEnvironment  string `json:"boshEnvironment"`
	BoshPath         string `json:"boshPath"`
	BaseManifestPath string `json:"baseManifestPath"`
	HomePath         string `json:"homePath"`
}

func loadConfig() (Config, error) {
	releaseRepoPath, err := getEnvOrFail("REPO_ROOT")
	if err != nil {
		return Config{}, err
	}

	releaseVersion, err := getEnvOrFail("RELEASE_VERSION")
	if err != nil {
		return Config{}, err
	}

	boshCACert, err := getEnvOrFail("BOSH_CA_CERT")
	if err != nil {
		return Config{}, err
	}

	boshClient, err := getEnvOrFail("BOSH_CLIENT")
	if err != nil {
		return Config{}, err
	}

	boshClientSecret, err := ge