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
    let(:proper