# frozen_string_literal: true

require 'rspec'

describe 'config/whitelist_cidrs.txt' do
  let(:template) { haproxy_job.template('config/whitelist_cidrs.txt') }

  context 'when ha_proxy.cidr_whitelist is provided' do
    context 'when an array of cidrs is provided' do
 