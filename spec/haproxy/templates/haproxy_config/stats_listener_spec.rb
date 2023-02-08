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
      expect(stats_listener).to include('bind *:9000')
      expect(stats_listener).to include('acl private src 0.0.0.0/32')
      expect(stats_listener).to include('http-request deny unless private')
      expect(stats_listener).to include('mode http')
      expect(stats_listener).to include('stats enable')
      expect(stats_listener).to include('stats hide-version')
      expect(stats_listener).to include('stats realm "Haproxy Statistics"')
      expect(stats_listener).to include('stats uri /foo')
      expect(stats_listener).to include('stats auth admin:secret')
    end

    context 'when ha_proxy.trusted_stats_cidrs is set' do
      let(:properties) do
        default_properties.merge({ 'trusted_stats_cidrs' => '1.2.3.4/32' })
      end

      it 'has the correct acl' do
        expect(stats_listener).to include('acl private src 1.2.3.4/32')
      end
    end

    context 'whe