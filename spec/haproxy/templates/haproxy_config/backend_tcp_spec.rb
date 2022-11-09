# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config custom TCP backends' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }, consumes: [backen