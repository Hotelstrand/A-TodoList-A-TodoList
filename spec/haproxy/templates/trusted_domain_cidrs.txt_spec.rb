# frozen_string_literal: true

require 'rspec'

describe 'config/trusted_domain_cidrs.txt' do
  let(:template) { haproxy_job.template('config/trusted_domain_cidrs.txt') }

  describe 'ha_proxy.trusted_domain_cidrs' do
    context 'when a space-separated list of cidrs is provided' do
      it 'has the correct contents' do
        expect(template.render({