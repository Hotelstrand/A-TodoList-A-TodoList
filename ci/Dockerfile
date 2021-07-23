FROM bosh/main-bosh-docker

ARG GINKGO_VERSION=v2.2.0

ENV DEBIAN_FRONTEND=noninteractive

# Install all necessary tools for haproxy testflight and dependency autobump
RUN apt-get update && apt-get install -y wget jq git vim nano python3-pip\
  && wget -q -O - https://raw.githubusercontent.com/starkandwayne/homebrew-cf/master/public.key | apt-key 