# frozen_string_literal: true

require 'rspec'

describe 'config/certs.ttar' do
  let(:template) { haproxy_job.template('config/certs.ttar') }

  describe 'ha_proxy.ssl_pem' do
    let(:ttar) do
      template.render({
        'ha_proxy' => {
          'ssl_pem' => ssl_pem
        }
      })
    end

    context 'when ssl_pem is an array of objects' do
      let(:ssl_pem) do
        [{
          'cert_chain' => 'cert_chain 0 contents',
          'private_key' => 'private_k