# frozen_string_literal: true

require 'rspec'
require 'tempfile'

describe 'config/haproxy.config frontend cf_tcp_routing' do
  let(:tcp_router_link) do
