# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config backend cf_tcp_routers' do
  let(:tcp_router_link) do
    Bosh::Template::Test::Lin