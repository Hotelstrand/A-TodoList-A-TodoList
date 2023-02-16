# frozen_string_literal: true

require 'rspec'

describe 'config/whitelist_cidrs.txt' do
  let(:template) { haproxy_job.template('config/whitelist_cidrs.txt') }

  context 'when ha_proxy.cidr_whitelist is provided' do
    context 'when an array of cidrs is provided' do
      it 'has the correct contents' do
        expect(template.render({
          'ha_proxy' => {
            'cidr_whitelist' => [
              '10.0.0.0/8',
              '192.168.2.0/24'
            ]
          }
        })).to eq(<<~EXPECTED)
          # generated from whitelist_cidrs.txt.erb

          # BEGIN whitelist cidrs
          # detected cidrs provided as array in cleartext format
