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
  