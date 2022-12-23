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
        'log_max_length' 