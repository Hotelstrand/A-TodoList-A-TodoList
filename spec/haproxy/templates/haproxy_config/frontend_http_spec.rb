# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config HTTP frontend' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:frontend_http) { haproxy_conf['frontend http-in'] }
  let(:properties) { {} }

  it 'binds to all interfaces by default' do
    expect(frontend_http).to include('bind :80')
  end

  context 'when ha_proxy.binding_ip is provided' do
    let(:properties) do
      { 'binding_ip' => '1.2.3.4' }
    end

    it 'binds to the provided ip' do
      expect(frontend_http).to include('bind 1.2.3.4:80')
    end

    context 'when ha_proxy.v4v6 is true and binding_ip is ::' do
      let(:properties) do
        { 'v4v6' => true, 'binding_ip' => '::' }
      end

      it 'enables ipv6' do
        expect(frontend_http).to include('bind :::80  v4v6')
      end
    end

    context 'when ha_proxy.accept_proxy is true' do
      let(:properties) do
        { 'accept_proxy' => true }
      end

      it 'sets accept-proxy' do
        expect(frontend_http).to include('bind :80 accept-proxy')
      end
    end
  end

  context 'when a custom ha_proxy.frontend_config is provided' do
    let(:properties) do
      { 'frontend_config' => 'custom config content' }
    end

    it 'includes the custom config' do
      expect(frontend_http).to include('custom config content')
    end
  end

  context 'when a ha_proxy.cidr_whitelist is provided' do
    let(:properties) do
      { 'cidr_whitelist' => ['172.168.4.1/32', '10.2.0.0/16'] }
    end

    it 'sets the correct acl and content accept rules' do
      expect(frontend_http).to include('acl whitelist src -f /var/vcap/jobs/haproxy/config/whitelist_cidrs.txt')
      expect(frontend_http).to include('tcp-request content accept if whitelist')
    end
  end

  context 'when a ha_proxy.cidr_blacklist is provided' do
    let(:properties) do
      { 'cidr_blacklist' => ['172.168.4.1/32', '10.2.0.0/16'] }
    end

    it 'sets the correct acl and content reject rules' do
      expect(frontend_http).to include('acl blacklist src -f /var/vcap/jobs/haproxy/config/blacklist_cidrs.txt')
      expect(frontend_http).to include('tcp-request content reject if blacklist')
    end
  end

  context 'when ha_proxy.block_all is provided' do
    let(:properties) do
      { 'block_all' => true }
    end

    it 'sets the correct content reject rules' do
      expect(frontend_http).to include('tcp-request content reject')
    end
  end

  it 'correct request capturing configuration' do
    expect(frontend_http).to include('capture request header Host len 256')
  end

  context 'when HTTP1 backend servers are available' do
    it 'has the uses the HTTP1 backend default backend' do
      expect(frontend_http).to include('default_backend http-routers-http1')
    end
  end

  context 'when only HTTP1 and HTTP2 backend servers are available' do
    let(:properties) do
      {
        'disable_backend_http2_websockets' => true,
        'enable_http2' => true,
        'backend_ssl' => 'verify'
      }
    end

    it 'uses the HTTP2 backend default backend' do
      expect(frontend_http).to include('default_backend http-routers-http2')
    end
  end

  context 'when only HTTP2 backend servers are available' do
    let(:properties) do
      {
        'disable_backend_http2_websockets' => false,
        'enable_http2' => true,
        'backend_match_http_protocol' => false,
        'backend_ssl' => 'verify'
      }
    end

    it 'uses the HTTP2 backend default backend' do
      expect(frontend_http).to include('default_backend http-routers-http2')
    end
  end

  context 'when ha_proxy.http_request_deny_conditions are provided' do
    let(:properties) do
      {
        'http_request_deny_conditions' => [{
          'condition' => [{
            'acl_name' => 'block_host',
            'acl_rule' => 'hdr_beg(host) -i login'
          }, {
            'acl_name' => 'whitelist_ips',
            'acl_rule' => 'src 5.22.5.11 5.22.5.12',
            'negate' => true
          }]
        }]
      }
    end

    it 'adds the correct acls and http-request deny rules' do
      expect(frontend_http).to include('acl block_host hdr_beg(host) -i login')
      expect(frontend_http).to include('acl whitelist_ips src 5.22.5.11 5.22.5.12')

      expect(frontend_http).to include('http-request deny if block_host !whitelist_ips')
    end
  end

  context 'when ha_proxy.headers are provided' do
    let(:properties) do
      { 'headers' => ['X-Application-ID: my-custom-header', 'MyCustomHeader: 3'] }
    end

    it 'adds the request headers' do
      expect(frontend_http).to include('http-request add-header X-Application-ID:\ my-custom-header ""')
      expect(frontend_http).to include('http-request add-header MyCustomHeader:\ 3 ""')
    end
  end

  context 'when ha_proxy.rsp_headers are provided' do
    let(:properties) do
      { 'rsp_headers' => ['X-Application-ID: my-c