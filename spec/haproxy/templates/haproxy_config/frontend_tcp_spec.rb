
# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config custom TCP frontends' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }, consumes: [backend_tcp_link]))
  end

  let(:backend_tcp_link) do
    Bosh::Template::Test::Link.new(
      name: 'tcp_backend',
      instances: [Bosh::Template::Test::LinkInstance.new(address: 'postgres.backend.com', name: 'postgres')]
    )
  end

  let(:frontend_tcp_redis) { haproxy_conf['frontend tcp-frontend_redis'] }
  let(:frontend_tcp_mysql) { haproxy_conf['frontend tcp-frontend_mysql'] }
  let(:frontend_tcp_postgres_via_link) { haproxy_conf['frontend tcp-frontend_postgres'] }

  let(:default_properties) do
    {
      'tcp_link_port' => 5432,
      'tcp' => [{
        'name' => 'redis',
        'port' => 6379,
        'backend_servers' => ['10.0.0.1', '10.0.0.2']
      }, {
        'name' => 'mysql',
        'port' => 3306,
        'backend_servers' => ['11.0.0.1', '11.0.0.2']
      }]
    }
  end

  let(:properties) { default_properties }

  it 'has the correct mode' do
    expect(frontend_tcp_redis).to include('mode tcp')
    expect(frontend_tcp_mysql).to include('mode tcp')
    expect(frontend_tcp_postgres_via_link).to include('mode tcp')
  end

  it 'has the correct default backend' do
    expect(frontend_tcp_redis).to include('default_backend tcp-redis')
    expect(frontend_tcp_mysql).to include('default_backend tcp-mysql')
    expect(frontend_tcp_postgres_via_link).to include('default_backend tcp-postgres')
  end

  it 'binds to all interfaces by default' do
    expect(frontend_tcp_redis).to include('bind :6379')
    expect(frontend_tcp_mysql).to include('bind :3306')
    expect(frontend_tcp_postgres_via_link).to include('bind :5432')
  end

  context 'when ha_proxy.binding_ip is provided' do
    let(:properties) do
      default_properties.merge({ 'binding_ip' => '1.2.3.4' })