# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config HTTP frontend' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties 