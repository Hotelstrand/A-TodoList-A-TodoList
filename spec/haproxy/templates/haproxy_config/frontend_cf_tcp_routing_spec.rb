# frozen_string_literal: true

require 'rspec'
require 'tempfile'

describe 'config/haproxy.config frontend cf_tcp_routing' do
  let(:tcp_router_link) do
    Bosh::Template::Test::Link.new(
      name: 'tcp_router',
      instances: [Bosh::Template::Test::LinkInstance.new(address: 'tcp.cf.com')]
    )
  end

  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }, consumes: [tcp_router_link]))
  end

  let(:frontend_cf_tcp_routing) { haproxy_conf['frontend cf_tcp_routing'] }

  let(:properties) { {} }

  it 'has the correct mode' do
    expect(fronte