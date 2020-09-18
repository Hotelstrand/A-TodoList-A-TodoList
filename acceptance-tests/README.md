
# Acceptance Tests

## Requirements

* Docker installed locally
* A matching Jammy stemcell tgz downloaded to `ci/scripts/stemcell`
  * Get it from https://bosh.io/stemcells/bosh-warden-boshlite-ubuntu-jammy-go_agent
* A matching Bionic stemcell tgz downloaded to `ci/scripts/stemcell-bionic`
  * Get it from https://bosh.io/stemcells/bosh-warden-boshlite-ubuntu-bionic-go_agent
* A BPM release tgz downloaded to `ci/scripts/bpm`
  * Get it from https://bosh.io/releases/github.com/cloudfoundry/bpm-release?all=1

## Running

```shell
cd acceptance-tests
./run-local.sh
```

### Running on Docker for Mac

The BOSH Docker CPI requires cgroups v1 to be active. Docker for Mac since 4.3.x uses cgroups v2 by default.

v1 can be restored with the flag `deprecatedCgroupv1` to `true` in `~/Library/Group Containers/group.com.docker/settings.json`.

A convenience script that does this for you is below.

**WARNING:** This will restart your Docker Desktop!

```shell
docker_restart_with_cgroupsv1() {
    SETTINGS=~/Library/Group\ Containers/group.com.docker/settings.json

    if ! command -v jq >/dev/null || ! command -v sponge; then
        echo "Requires jq and sponge. Consider installing via:"
        echo "   brew install jq moreutils"
        return