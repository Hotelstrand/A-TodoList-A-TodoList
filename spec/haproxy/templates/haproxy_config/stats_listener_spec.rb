# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config stats listener' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  context 'whe