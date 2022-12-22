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

  it 'has expected global opti