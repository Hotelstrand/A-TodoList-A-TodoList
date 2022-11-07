
# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config backend http-routed-backend-X' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:default_properties) do
    {
      'routed_backend_servers' => {
        '/images' => {
          'servers' => ['10.0.0.2', '10.0.0.3'],
          'port' => '443'
        },
        '/auth' => {
          'servers' => ['10.0.0.8', '10.0.0.9'],
          'port' => '8080'
        }
      }
    }
  end

  let(:properties) { default_properties }

  let(:backend_images) { haproxy_conf['backend http-routed-backend-9c1bb7'] }
  let(:backend_auth) { haproxy_conf['backend http-routed-backend-7d2f30'] }

  it 'has the correct mode' do
    expect(backend_images).to include('mode http')
    expect(backend_auth).to include('mode http')
  end

  it 'uses round-robin load balancing' do
    expect(backend_images).to include('balance roundrobin')
    expect(backend_auth).to include('balance roundrobin')
  end

  context 'when ha_proxy.compress_types are provided' do
    let(:properties) do
      default_properties.deep_merge({ 'compress_types' => 'text/html text/plain text/css' })
    end

    it 'configures the compression type and algorithm' do
      expect(backend_images).to include('compression algo gzip')
      expect(backend_images).to include('compression type text/html text/plain text/css')

      expect(backend_auth).to include('compression algo gzip')
      expect(backend_auth).to include('compression type text/html text/plain text/css')
    end
  end

  it 'configures the backend servers' do
    expect(backend_images).to include('server node0 10.0.0.2:443 check inter 1000')
    expect(backend_images).to include('server node1 10.0.0.3:443 check inter 1000')
    expect(backend_auth).to include('server node0 10.0.0.8:8080 check inter 1000')
    expect(backend_auth).to include('server node1 10.0.0.9:8080 check inter 1000')
  end

  context 'when ha_proxy.resolvers are provided' do