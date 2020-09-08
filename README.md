BOSH Release for haproxy
===========================

Questions? Pop in our [slack channel](https://cloudfoundry.slack.com/messages/haproxy-boshrelease/)!

This BOSH release is an attempt to get a more customizable/secure haproxy release than what
is provided in [cf-release](https://github.com/cloudfoundry/cf-release). It allows users to
blacklist internal-only domains, preventing potential Host header spoofing from allowing
unauthorized access of internal APIs. It also allows for better control over haproxy's
timeouts, for greater resiliency under heavy load.

Usage
-----

To deploy this BOSH release:

```
git clone https://github.com/cloudfoundry-community/haproxy-boshrelease.git
