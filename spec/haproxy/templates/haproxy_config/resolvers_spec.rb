# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config resolvers' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'when ha_proxy.resolvers are provided' do
    let(:resolvers_default) { haproxy_conf['resolvers default'] }

    let(:default_properties) do
      {
        'resolvers' => [
          { 'public' => '1.1.1.1' },
          { 'private' => '10.1.1.1' }
        ]
      }
    end

    let(:properties) { default_properties }

    it 'configures a resolver' do
      expect(resolvers_default).to include('hold valid 10s')
      expect(resolvers_default).to include('timeout retry 1s')
      expect(resolvers_default).