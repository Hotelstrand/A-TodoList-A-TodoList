# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config rate limiting' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:frontend_http) { haproxy_conf['frontend http-in'] }
  let(:frontend_https) { haproxy_conf['frontend https-in'] }

  let(:properties) { {} }

  let(:default_properties) do
    {
      'ssl_pem' => 'ssl pem contents' # required for https-in frontend
    }
  end

  context 'when ha_proxy.requests_rate_limit properties "window_size", "table_size" are provided' do
    let(:backend_req_rate) { haproxy_conf['backend st_http_req_rate'] }

    let(:request_limit_base_properties) do
      {
        'requests_