# frozen_string_literal: true

require 'rspec'

describe 'config/client-revocation-list.pem' do
  let(:template) { haproxy_job.template('config/client-revocation-list.pem') }

  describe 'ha_proxy.client_revocation_list' do
    it 'has the correct contents' do
      expect(template.render({
        'ha_proxy' => {
          'client_revocation_list' => 'foobarbaz'
        