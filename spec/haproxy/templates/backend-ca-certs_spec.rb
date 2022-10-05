# frozen_string_literal: true

require 'rspec'

describe 'config/backend-ca-certs.pem' do
  let(:template) { haproxy_job.template('config/backend-ca-certs.pem') }

  describe 'ha_proxy.backend_ca_file' do
    it 'has the correct contents' do
      expect(template.render({
        'ha_proxy' => {
          'backend_ca_file' => 'foobarbaz'
      