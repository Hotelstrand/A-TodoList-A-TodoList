# frozen_string_literal: true

require 'rspec'

describe 'config/cidrs.ttar' do
  let(:template) { haproxy_job.template('config/cidrs.ttar') }

  describe 'ha_proxy.cidrs_in_file' do
    let(:ttar) do
      template.render({
        'ha_proxy' => {
          'cidrs_in_file' => [{
            'cidrs' => [
              '5.22.1.3',
              '5.22.12.3'
            ],
            'name' => 'sample_cidrs'
          }]
        }
      })
    end

    it 'has the correct contents' do
      expect(ttar_entry(ttar, '/var/