# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config stats listener' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'when ha_proxy.stats_enable is true' do
    let(:default_properties) do
      {
        'syslog_server' => '/dev/log',
        'stats_enable' => true,
        'stats_user' => 'admin',
        'stats_password' => 'secret',
        'stats_uri' => 'foo'
      }
    end

    let(:properties) { default_properties }

    let(:stats_listener) { haproxy_conf['listen stats'] }

    it 'sets up a stats listener for each process' do
      expect(stats_listener).to inclu