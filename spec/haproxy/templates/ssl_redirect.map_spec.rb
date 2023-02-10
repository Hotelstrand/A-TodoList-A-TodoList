# frozen_string_literal: true

require 'rspec'

describe 'config/ssl_redirect.map' do
  let(:template) { haproxy_job.template('config/ssl_redirect.map') }

  context 'when ha_proxy.https_redir