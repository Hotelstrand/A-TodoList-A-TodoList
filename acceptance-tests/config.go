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

func loadConfig() (C