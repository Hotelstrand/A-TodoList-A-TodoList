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

    co