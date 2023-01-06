# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config healthcheck listeners' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'when ha_proxy.enable_health_check_http is true' do
    let