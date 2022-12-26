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

    it 'sets the number of