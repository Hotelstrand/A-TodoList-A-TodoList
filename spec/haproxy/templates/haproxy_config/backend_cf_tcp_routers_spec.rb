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
    expect(backend_cf_tcp_routers).to include('mod