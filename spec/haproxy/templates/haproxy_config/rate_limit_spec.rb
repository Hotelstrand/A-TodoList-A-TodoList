# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config rate limiting' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:frontend_http) { haproxy_conf['frontend http-in'] }
  let(:fro