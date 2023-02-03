# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config resolvers' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'when ha_proxy.resolvers are provided' do
    let(:resolvers_default) { 