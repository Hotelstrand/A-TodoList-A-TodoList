# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config custom TCP backends' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }, consumes: [backend_tcp_link]))
  end

  let(:backend_tcp_link) do
    Bosh::Template::Test::Link.new(
      name: 'tcp_backend',
      instances: [
        # will appear in same AZ
        Bosh::Template::Test::LinkInstance.new(address: 'postgres.az1.com', name: 'postgres', az: 'az1'),

        # will appear in another AZ
        Bosh::Template::Test::LinkInstance.new(address: 'postgres.az2.com', name: 'postgres', az: 'az2')
      ]
    )
  end

  let(:backend_tcp_redis) { haproxy_conf['backend tcp-redis'] }
  let(:backend_tcp_mysql) { haproxy_conf['backend tcp-mysql'] }
  let(:backend_tcp_postgres_via_link) { haproxy_conf['backend tcp-postgres'] }

  let(:default_properties) do
    {
      'tcp_link_port' => 5432,
      'tcp' => [{
        'name' => 'redis',
        'port' => 6379,
        'backend_servers' => ['10.0.0.1', '10.0.0.2']
      }, {
        'name' =>