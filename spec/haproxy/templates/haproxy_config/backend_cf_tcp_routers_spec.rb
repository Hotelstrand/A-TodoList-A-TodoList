# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config backend cf_tcp_routers' do
  let(:tcp_router_link) do
    Bosh::Template::Test::Link.new(
      name: 'tcp_router',
      instances: [Bosh::Template::Test::LinkInstance.new(address: 'tcp.cf.com')]
    )
  end

  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }, consumes: [tcp_router_link]))
  end

  let(:backend_cf_tcp_routers) { haproxy_conf['backend cf_tcp_routers'] }

  let(:properties) { {} }

  it 'has the correct mode' do
    expect(backend_cf_tcp_routers).to include('mode tcp')
  end

  it 'has a healthcheck' do
    expect(backend_cf_tcp_routers).to include('option httpchk GET /health')
  end

  context 'when a custom ha_proxy.tcp_backend_config is provided' do
    let(:properties) do
      {
        'tcp_backend_config' => 'custom backend config'
      }
    end

    it 'is included in the backend configuration' do
      expect(backend_cf_tcp_routers).to include('custom backend config')
    end
  end

  it 'has the co