# frozen_string_literal: true

require 'rspec'

describe 'config/client-ca-certs.pem' do
  let(:template) { haproxy_job.template('config/client-ca-certs.pem') }

  describe 'ha_proxy.client_ca_file' do
    it 'has the correct contents' do
      expect(template.render({
        'ha_proxy' => {
          'client_ca_file' => 'foobarbaz'
        }
      })).to eq("\nfoobarbaz\n\n")
    end

    context 'when ha_proxy.client_ca_file is not provided' do
      it 'is empty' do
        expect(template.render({})).