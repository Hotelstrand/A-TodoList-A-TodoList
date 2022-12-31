# frozen_string_literal: true

require 'rspec'
require 'haproxy-tools'

describe 'config/haproxy.config global and default options' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:global) { haproxy_conf['global'] }
  let(:defaults) { haproxy_conf['defaults'] }

  let(:properties) { {} }

  it 'renders a valid haproxy template' do
    expect do
      HAProxy::Parser.new.parse(template.render({}))
    end.not_to raise_error
  end

  it 'has expected defaults' do
    expect(defaults).to include('log global')
    expect(defaults).to include('option log-health-checks')
    expect(defaults).to include('option log-separate-errors')
    expect(defaults).to include('option http-server-close')
    expect(defaults).to include('option idle-close-on-response')
    expect(defaults).to include('option httplog')
    expect(defaults).to include('option forwardfor')
    expect(defaults).to include('option contstats')
  end

  it 'has expected global options' do
    expect(global).to include('daemon')
    expect(global).to include('user vcap')
    expect(global).to include('group vcap')
    expect(global).to include('spread-checks 4')
    expect(global).to include('stats timeout 2m')
  end

  context 'when ha_proxy.raw_config is provided' do
    it 'replaces the entire haproxy config contents' do
      expect(template.render({
        'ha_proxy' => {
          'raw_config' => 'custom_config'
        }
      })).to eq("custom_config\n")
    end
  end

  context 'when ha_proxy.syslog_server is provided' do
    let(:properties) do
      {
        'syslog_server' => '/my/server'
      }
    end

    it 'configures logging correctly' do
      expect(global).to include('log /my/server len 1024 format raw syslog info')
    end
  end

  context 'when ha_proxy.log_max_length is provided' do
    let(:properties) do
      {
        'log_max_length' => 9999
      }
    end

    it 'configures logging correctly' do
      expect(global).to include('log stdout len 9999 format raw syslog info')
    end
  end

  context 'when ha_proxy.log_format is provided' do
    let(:properties) do
      {
        'log_format' => 'custom-format'
      }
    end

    it 'configures logging correctly' do
      expect(global).to include('log stdout len 1024 format custom-format syslog info')
    end
  end

  context 'when ha_proxy.log_level is provided' do
    let(:properties) do
      {
        'log_level' => 'trace'
      }
    end

    it 'configures logging correctly' do
      expect(global).to include('log stdout len 1024 format raw syslog trace')
    end
  end

  context 'when ha_proxy.global_config is provided' do
    let(:properties) do
      {
        'global_config' => 'custom-global-config'
      }
    end

    it 'adds custom global config' do
      expect(global).to include('custom-global-config')
    end
  end

  context 'when ha_proxy.nbthread is provided' do
    let(:properties) do
      {
        'nbthread' => 7
      }
    end

    it 'sets nbthread' do
      expect(global).to include('nbthread 7')
    end
  end

  context 'when ha_proxy.disable_tls_10 is provided' do
    let(:properties) do
      {
        'disable_tls_10' => true
      }
    end

    it 'disables TLS 1.0' do
      expect(global).to include('ssl-default-server-options no-sslv3 no-tlsv10 no-tls-tickets')
      expect(global).to include('ssl-default-bind-options no-sslv3 no-tlsv10 no-tls-tickets')
    end
  end

  context 'when ha_proxy.disable_tls_11 is provided' do
    let(:properties) do
      {
        'disable_tls_11' => true
      }
    end

    it 'disables TLS 1.1' do
      expect(global).to include('ssl-default-server-options no-sslv3 no-tlsv11 no-tls-tickets')
      expect(global).to include('ssl-default-bind-options no-sslv3 no-tlsv11 no-tls-tickets')
    end
  end

  context 'when ha_proxy.disable_tls_12 is provided' do
    let(:properties) do
      {
        'disable_tls_12' => true
      }
    end

    it 'disables TLS 1.2' do
      expect(global).to include('ssl-default-server-options no-sslv3 no-tlsv12 no-tls-tickets')
      expect(global).to include('ssl-default-bind-options no-sslv3 no-tlsv12 no-tls-tickets')
    end
  end

  context 'when ha_proxy.disable_tls_13 is provided' do
    let(:properties) do
      {
        'disable_tls_13' => true
      }
    end

    it 'disables TLS 1.3' do
      expect(global).to include('ssl-default-server-options no-sslv3 no-tlsv13 no-tls-tickets')
      expect(global).to include('ssl-default-bind-options no-sslv3 no-tlsv13 no-tls-tickets')
    end
  end

  context 'when ha_proxy.disable_tls_tickets is provided' do
    let(:properties) do
      {
        'disable_tls_tickets' => false
      }
    end

    it 'enables TLS tickets when changed from default' do
      expect(global).to include('ssl-default-server-options no-sslv3')
      expect(global).to include('ssl-default-bind-options no-sslv3')
    end
  end

  context 'when ha_proxy.ssl_ciphers is provided' do
    let(:properties) do
      {
        'ssl_ciphers' => 'ECDHE-ECDSA-CHACHA20-POLY1305'
      }
    end

    it 'overrides the allowed ciphers' do
      expect(global).to include('ssl-default-server-ciphers ECDHE-ECDSA-CHACHA20-POLY1305')
      expect(global).to include('ssl-default-bind-ciphers ECDHE-ECDSA-CHACHA20-POLY1305')
    end
  end

  context 'when ha_proxy.ssl_ciphersuites is provided' do
    let(:properties) do
      {
        'ssl_ciphersuites' => 'TLS_AES_128_GCM_SHA256'
      }
    end

    it 'overrides the allowed ciphers' do
      expect(global).to include('ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256')
      expect(global).to include('ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256')
    end
  end

  context 'when ha_proxy.max_connections is provided' do
    let(:properties) do
      {
        'max_connections' => 9999
      }
    end

    it 'sets the number of max connections' do
      expect(global).to include('maxconn 9999')
      expect(defaults).to include('maxconn 9999')
    end
  end

  context 'when ha_proxy.reload_hard_stop_after is provided' do
    let(:properties) do
      {
        'reload_hard_stop_after' => '30m'
      }
    end

    it 'sets hard-stop-after' do
      expect(global).to include('hard-stop-after 30m')
    end
  end

  context 'when ha_proxy.lua_scripts is provided' do
    let(:properties) do
      {
        'lua_scripts' => [
          '/var/vcap/packages/something/something/darkside.lua'
        ]
      }
    end

    it 'includes the external lua script' do
      expect(global).to include('lua-load /var/vcap/packages/something/something/darkside.lua')
    end
  end

  context 'when ha_proxy.lua_scripts_per_thread is provided' do
    let(:properties) do
      {
        'lua_scripts_per_thread' => [
          '/var/vcap/packages/something/something/darkside.lua'
        ]
      }
    end

    it 'includes the external lua script' do
      expect(global).to include('lua-load-per-thread /var/vcap/packages/something/something/darkside.lua')
    end
  end

  context 'when ha_proxy.default_dh_param is provided' do
    let(:properties) do
      {
        'default_dh_param' => 8888
      }
    end

    it 'sets tune.ssl.default-dh-param' do
      expect(global).to include('tune.ssl.default-dh-param 8888')
    end
  end

  context 'when ha_proxy.buffer_size_bytes is provided' do
    let(:properties) do
      {
        'buffer_size_bytes' => 7777
      }
    end

    it 'sets tune.bufsize' do
      expect(global).to include('tune.bufsize 7777')
    end
  end

  context 'when ha_proxy.max_rewrite is provided' do
    let(:properties) do
      {
        'max_rewrite' => 6666
      }
    end

    it 'sets tune.maxrewrite' do
      expect(global).to include('tune.maxrewrite 6666')
    end
  end

  context 'when ha_proxy.drain_enable is false' do
    let(:properties) do
      {
        'drain_enable' => false,
        'drain_frontend_grace_time' => 12
      }
    end

    it 'aborts with a meaningful error message' do
      expect { global }.to raise_error(/Conflicting configuration: drain_enable must be true to use drain_frontend_grace_time/)
    end
  end

  context 'when ha_proxy.connect_timeout is provided' do
    let(:properties) do
      {
        'connect_timeout' => 4
      }
    end

    it 'sets timeout connect in milliseconds' do
      expect(defaults).to include(/timeout connect\s+4000ms/)
    end
  end

  context 'when ha_proxy.client_timeout is provided' do
    let(:properties) do
      {
        'client_timeout' => 5