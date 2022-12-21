
# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config HTTPS frontend' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:frontend_https) { haproxy_conf['frontend https-in'] }
  let(:default_properties) do
    {
      'ssl_pem' => 'ssl pem contents'
    }
  end

  let(:properties) { default_properties }

  it 'binds to all interfaces by default' do
    expect(frontend_https).to include('bind :443  ssl crt /var/vcap/jobs/haproxy/config/ssl')
  end

  context 'when ha_proxy.binding_ip is provided' do
    let(:properties) do
      default_properties.merge({ 'binding_ip' => '1.2.3.4' })
    end

    it 'binds to the provided ip' do
      expect(frontend_https).to include('bind 1.2.3.4:443  ssl crt /var/vcap/jobs/haproxy/config/ssl')
    end

    context 'when ha_proxy.v4v6 is true and binding_ip is ::' do
      let(:properties) do
        default_properties.merge({ 'v4v6' => true, 'binding_ip' => '::' })
      end

      it 'enables ipv6' do
        expect(frontend_https).to include('bind :::443  ssl crt /var/vcap/jobs/haproxy/config/ssl  v4v6')
      end
    end

    context 'when ha_proxy.accept_proxy is true' do
      let(:properties) do
        default_properties.merge({ 'accept_proxy' => true })
      end

      it 'sets accept-proxy' do
        expect(frontend_https).to include('bind :443 accept-proxy ssl crt /var/vcap/jobs/haproxy/config/ssl')
      end
    end
  end

  context 'when ha_proxy.disable_domain_fronting is true' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => true })
    end

    it 'disables domain fronting by checking SNI against the Host header' do
      expect(frontend_https).to include('http-request set-var(txn.host) hdr(host),field(1,:),lower')
      expect(frontend_https).to include('acl ssl_sni_http_host_match ssl_fc_sni,lower,strcmp(txn.host) eq 0')
      expect(frontend_https).to include('http-request deny deny_status 421 if { ssl_fc_has_sni } !ssl_sni_http_host_match')
    end
  end

  context 'when ha_proxy.disable_domain_fronting is mtls_only' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => 'mtls_only' })
    end

    it 'disables domain fronting by checking SNI against the Host header for mtls connections only' do
      expect(frontend_https).to include('http-request set-var(txn.host) hdr(host),field(1,:),lower')
      expect(frontend_https).to include('acl ssl_sni_http_host_match ssl_fc_sni,lower,strcmp(txn.host) eq 0')
      expect(frontend_https).to include('http-request deny deny_status 421 if { ssl_fc_has_sni } { ssl_c_used } !ssl_sni_http_host_match')
    end
  end

  context 'when ha_proxy.disable_domain_fronting is false (the default)' do
    it 'allows domain fronting' do
      expect(frontend_https).not_to include(/http-request deny deny_status 421/)
    end
  end

  context 'when ha_proxy.disable_domain_fronting is an invalid value' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => 'foobar' })
    end

    it 'aborts with a meaningful error message' do
      expect do
        frontend_https
      end.to raise_error(/Unknown 'disable_domain_fronting' option: foobar. Known options: true, false or 'mtls_only'/)
    end
  end

  context 'when mutual tls is disabled' do
    let(:properties) do
      default_properties.merge({ 'client_cert' => false })
    end

    it 'does not add mTLS headers' do
      expect(frontend_https).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
      expect(frontend_https).not_to include(/http-request set-header X-SSL-Client/)
    end
  end

  context 'when mutual tls is enabled' do
    let(:properties) do
      default_properties.merge({ 'client_cert' => true })
    end

    it 'configures ssl to use the client ca' do
      expect(frontend_https).to include('bind :443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional')
    end

    context 'when ha_proxy.client_cert_ignore_err is all' do
      let(:properties) do
        default_properties.merge({ 'client_cert' => true, 'client_cert_ignore_err' => 'all' })
      end

      it 'adds the crt-ignore-err and ca-ignore-err flags' do
        expect(frontend_https).to include('bind :443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional crt-ignore-err all ca-ignore-err all')
      end

      context 'when client_cert is not enabled' do
        let(:properties) do
          default_properties.merge({ 'client_cert_ignore_err' => 'all' })
        end

        it 'aborts with a meaningful error message' do
          expect do
            frontend_https
          end.to raise_error(/Conflicting configuration: must enable client_cert to use client_cert_ignore_err/)
        end
      end
    end

    context 'when ha_proxy.client_revocation_list is provided' do
      let(:properties) do
        default_properties.merge({ 'client_cert' => true, 'client_revocation_list' => 'client_revocation_list contents' })
      end

      it 'references the crl list' do
        expect(frontend_https).to include('bind :443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional crl-file /var/vcap/jobs/haproxy/config/client-revocation-list.pem')
      end

      context 'when client_cert is not enabled' do
        let(:properties) do
          default_properties.merge({ 'client_revocation_list' => 'client_revocation_list contents' })
        end

        it 'aborts with a meaningful error message' do
          expect do
            frontend_https
          end.to raise_error(/Conflicting configuration: must enable client_cert to use client_revocation_list/)
        end
      end
    end
  end

  describe 'ha_proxy.forwarded_client_cert' do
    context 'when ha_proxy.forwarded_client_cert is always_forward_only' do
      let(:properties) do
        default_properties.merge({ 'forwarded_client_cert' => 'always_forward_only' })
      end

      it 'does not delete mTLS headers' do
        expect(frontend_https).not_to include(/http-request del-header X-Forwarded-Client-Cert/)
        expect(frontend_https).not_to include(/http-request del-header X-SSL-Client/)
      end

      it 'does not add mTLS headers' do
        expect(frontend_https).not_to include(/http-request set-header X-Fowarded-Client-Cert/)
        expect(frontend_https).not_to include(/http-request set-header X-SSL-Client/)
      end
    end

    context 'when ha_proxy.forwarded_client_cert is forward_only' do
      let(:properties) do
        default_properties.merge({ 'forwarded_client_cert' => 'forward_only' })
      end

      it 'deletes mTLS headers' do
        expect(frontend_https).to include('http-request del-header X-Forwarded-Client-Cert')
        expect(frontend_https).to include('http-request del-header X-SSL-Client')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-Session-ID')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-Verify')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-Subject-DN')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-Subject-CN')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-Issuer-DN')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-NotBefore')
        expect(frontend_https).to include('http-request del-header X-SSL-Client-NotAfter')
      end

      it 'does not add mTLS headers' do
        expect(frontend_https).not_to include(/http-request set-header X-Fowarded-Client-Cert/)
        expect(frontend_https).not_to include(/http-request set-header X-SSL-Client/)
      end

      context 'when mutual TLS is enabled' do
        let(:properties) do
          default_properties.merge({
            'client_cert' => true,
            'forwarded_client_cert' => 'forward_only'
          })
        end

        it 'deletes mTLS headers when mTLS is not used' do
          expect(frontend_https).to include('http-request del-header X-Forwarded-Client-Cert if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client            if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-Session-ID if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-Verify     if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-Subject-DN if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-Subject-CN if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-Issuer-DN  if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-NotBefore  if ! { ssl_c_used }')
          expect(frontend_https).to include('http-request del-header X-SSL-Client-NotAfter   if ! { ssl_c_used }')
        end

        it 'does not add mTLS headers' do
          expect(frontend_https).not_to include(/http-request set-header X-Fowarded-Client-Cert/)
          expect(frontend_https).not_to include(/http-request set-header X-SSL-Client/)
        end
      end
    end

    context 'when ha_proxy.forwarded_client_cert is sanitize_set (the default)' do
      it 'always deletes mTLS headers' do
        expect(frontend_https).to include('http-request del-header X-Forwarded-Client-Cert')