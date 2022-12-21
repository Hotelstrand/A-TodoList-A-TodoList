# frozen_string_literal: true

require 'rspec'
require 'haproxy-tools'

describe 'config/haproxy.config global and default options' do
  let(:haproxy_conf) do
    parse_haproxy_config(temp