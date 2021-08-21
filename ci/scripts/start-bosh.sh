
#!/usr/bin/env bash

set -eo pipefail

function generate_certs() {
  local certs_dir
  certs_dir="${1}"

  pushd "${certs_dir}"

    jq -ner --arg "ip" "${OUTER_CONTAINER_IP}" '{
      "variables": [
        {
          "name": "docker_ca",
          "type": "certificate",
          "options": {
            "is_ca": true,
            "common_name": "ca"
          }
        },
        {
          "name": "docker_tls",
          "type": "certificate",
          "options": {
            "extended_key_usage": [
              "server_auth"
            ],
            "common_name": $ip,
            "alternative_names": [ $ip ],
            "ca": "docker_ca"
          }
        },
        {
          "name": "client_docker_tls",
          "type": "certificate",
          "options": {