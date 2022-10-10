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
          'private_key' => 'private_key 0 contents'
        }, {
          'cert_chain' => 'cert_chain 1 contents',
          'private_key' => 'private_key 1 contents'
        }]
      end

      it 'has the correct contents' do
        expect(ttar_entry(ttar, '/var/vcap/jobs/haproxy/config/ssl/cert-0.pem')).to eq(<<~EXPECTED)

          cert_chain 0 contents
          private_key 0 contents

        EXPECTED

        expect(ttar_entry(ttar, '/var/vcap/jobs/haproxy/config/ssl/cert-1.pem')).to eq(<<~EXPECTED)

          cert_chain 1 contents
          private_key 1 contents


        EXPECTED
      end
    end

    context 'when ssl_pem is provided as an array of strings' do
      let(:ssl_pem) do
        [
          'cert 0 contents',
          'cert 1 contents'
        ]
      end

      it 'has the correct contents' do
        expect(ttar_entry(ttar, '/var/vcap/jobs/