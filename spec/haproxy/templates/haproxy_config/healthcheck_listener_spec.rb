# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config healthcheck listeners' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'when ha_proxy.enable_health_check_http is true' do
    let(:healthcheck_listener) { haproxy_conf['listen health_check_http_url'] }

    let(:properties) do
      {
        'enable_health_check_http' => true
      }
    end

    it 'adds a health check listener for the http-routers-http1' do
      expect(healthcheck_listener).to include('bind :8080')
      expect(healthcheck_listener).to include('mode http')
      expect(healthcheck_listener).to include('option httpclose')
      expect