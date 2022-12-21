
# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config HTTPS Websockets frontend' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:frontend_wss) { haproxy_conf['frontend wss-in'] }

  let(:default_properties) do
    {
      'enable_4443' => true,
      'ssl_pem' => 'ssl pem contents'
    }
  end

  let(:properties) { default_properties }

  it 'binds to all interfaces by default' do
    expect(frontend_wss).to include('bind :4443  ssl crt /var/vcap/jobs/haproxy/config/ssl')
  end

  context 'when ha_proxy.binding_ip is provided' do
    let(:properties) do
      default_properties.merge({ 'binding_ip' => '1.2.3.4' })
    end

    it 'binds to the provided ip' do
      expect(frontend_wss).to include('bind 1.2.3.4:4443  ssl crt /var/vcap/jobs/haproxy/config/ssl')
    end

    context 'when ha_proxy.v4v6 is true and binding_ip is ::' do
      let(:properties) do
        default_properties.merge({ 'v4v6' => true, 'binding_ip' => '::' })
      end

      it 'enables ipv6' do
        expect(frontend_wss).to include('bind :::4443  ssl crt /var/vcap/jobs/haproxy/config/ssl  v4v6')
      end
    end

    context 'when ha_proxy.accept_proxy is true' do
      let(:properties) do
        default_properties.merge({ 'accept_proxy' => true })
      end

      it 'sets accept-proxy' do
        expect(frontend_wss).to include('bind :4443 accept-proxy ssl crt /var/vcap/jobs/haproxy/config/ssl')
      end
    end
  end

  context 'when ha_proxy.disable_domain_fronting is true' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => true })
    end

    it 'disables domain fronting by checking SNI against the Host header' do
      expect(frontend_wss).to include('http-request set-var(txn.host) hdr(host),field(1,:),lower')
      expect(frontend_wss).to include('acl ssl_sni_http_host_match ssl_fc_sni,lower,strcmp(txn.host) eq 0')
      expect(frontend_wss).to include('http-request deny deny_status 421 if { ssl_fc_has_sni } !ssl_sni_http_host_match')
    end
  end

  context 'when ha_proxy.disable_domain_fronting is mtls_only' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => 'mtls_only' })
    end

    it 'disables domain fronting by checking SNI against the Host header for mtls connections only' do
      expect(frontend_wss).to include('http-request set-var(txn.host) hdr(host),field(1,:),lower')
      expect(frontend_wss).to include('acl ssl_sni_http_host_match ssl_fc_sni,lower,strcmp(txn.host) eq 0')
      expect(frontend_wss).to include('http-request deny deny_status 421 if { ssl_fc_has_sni } { ssl_c_used } !ssl_sni_http_host_match')
    end
  end

  context 'when ha_proxy.disable_domain_fronting is false (the default)' do
    it 'allows domain fronting' do
      expect(frontend_wss).not_to include(/http-request deny deny_status 421/)
    end
  end

  context 'when ha_proxy.disable_domain_fronting is an invalid value' do
    let(:properties) do
      default_properties.merge({ 'disable_domain_fronting' => 'foobar' })
    end

    it 'aborts with a meaningful error message' do
      expect do
        frontend_wss
      end.to raise_error(/Unknown 'disable_domain_fronting' option: foobar. Known options: true, false or 'mtls_only'/)
    end
  end

  context 'when mutual tls is enabled' do
    let(:properties) do
      default_properties.merge({ 'client_cert' => true })
    end

    it 'configures ssl to use the client ca' do
      expect(frontend_wss).to include('bind :4443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional')
    end

    context 'when ha_proxy.client_cert_ignore_err is all' do
      let(:properties) do
        default_properties.merge({ 'client_cert' => true, 'client_cert_ignore_err' => 'all' })
      end

      it 'adds the crt-ignore-err and ca-ignore-err flags' do
        expect(frontend_wss).to include('bind :4443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional crt-ignore-err all ca-ignore-err all')
      end

      context 'when client_cert is not enabled' do
        let(:properties) do
          default_properties.merge({ 'client_cert_ignore_err' => true })
        end

        it 'aborts with a meaningful error message' do
          expect do
            frontend_wss
          end.to raise_error(/Conflicting configuration: must enable client_cert to use client_cert_ignore_err/)
        end
      end
    end

    context 'when ha_proxy.client_revocation_list is provided' do
      let(:properties) do
        default_properties.merge({ 'client_cert' => true, 'client_revocation_list' => 'client_revocation_list contents' })
      end

      it 'references the crl list' do
        expect(frontend_wss).to include('bind :4443  ssl crt /var/vcap/jobs/haproxy/config/ssl  ca-file /etc/ssl/certs/ca-certificates.crt verify optional crl-file /var/vcap/jobs/haproxy/config/client-revocation-list.pem')
      end

      context 'when client_cert is not enabled' do
        let(:properties) do
          default_properties.merge({ 'client_revocation_list' => 'client_revocation_list contents' })
        end

        it 'aborts with a meaningful error message' do
          expect do
            frontend_wss
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
        expect(frontend_wss).not_to include('http-request del-header X-Forwarded-Client-Cert')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-Session-ID')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-Verify')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-Subject-DN')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-Subject-CN')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-Issuer-DN')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-NotBefore')
        expect(frontend_wss).not_to include('http-request del-header X-SSL-Client-NotAfter')
      end

      it 'does not add mTLS headers' do
        expect(frontend_wss).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
        expect(frontend_wss).not_to include(/http-request set-header X-SSL-Client/)
      end
    end

    context 'when ha_proxy.forwarded_client_cert is forward_only' do
      let(:properties) do
        default_properties.merge({ 'forwarded_client_cert' => 'forward_only' })
      end

      it 'deletes mTLS headers' do
        expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter')
      end

      it 'does not add mTLS headers' do
        expect(frontend_wss).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
        expect(frontend_wss).not_to include(/http-request set-header X-SSL-Client/)
      end

      context 'when mutual TLS is enabled' do
        let(:properties) do
          default_properties.merge({
            'client_cert' => true,
            'forwarded_client_cert' => 'forward_only'
          })
        end

        it 'deletes mTLS headers when mTLS is not used' do
          expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client            if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify     if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN  if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore  if ! { ssl_c_used }')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter   if ! { ssl_c_used }')
        end

        it 'does not add mTLS headers' do
          expect(frontend_wss).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
          expect(frontend_wss).not_to include(/http-request set-header X-SSL-Client/)
        end
      end
    end

    context 'when ha_proxy.forwarded_client_cert is sanitize_set (the default)' do
      it 'always deletes mTLS headers' do
        expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter')
      end

      it 'does not add mTLS headers' do
        expect(frontend_wss).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
        expect(frontend_wss).not_to include(/http-request set-header X-SSL-Client/)
      end

      context 'when mutual TLS is enabled' do
        let(:properties) do
          default_properties.merge({ 'client_cert' => true })
        end

        it 'always deletes mTLS headers' do
          expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter')
        end

        it 'writes mTLS headers when mTLS is used' do
          expect(frontend_wss).to include('http-request set-header X-Forwarded-Client-Cert %[ssl_c_der,base64]          if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client            %[ssl_c_used]                if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Session-ID %[ssl_fc_session_id,hex]     if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Verify     %[ssl_c_verify]              if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-NotBefore  %{+Q}[ssl_c_notbefore]       if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-NotAfter   %{+Q}[ssl_c_notafter]        if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-DN %{+Q}[ssl_c_s_dn,base64]     if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-CN %{+Q}[ssl_c_s_dn(cn),base64] if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Issuer-DN  %{+Q}[ssl_c_i_dn,base64]     if { ssl_c_used }')
        end

        context 'when ha_proxy.legacy_xfcc_header_mapping is true' do
          let(:properties) do
            default_properties.merge({ 'client_cert' => true, 'legacy_xfcc_header_mapping' => true })
          end

          it 'writes mTLS headers without base64 encoding when mTLS is used' do
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-DN %{+Q}[ssl_c_s_dn]            if { ssl_c_used }')
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-CN %{+Q}[ssl_c_s_dn(cn)]        if { ssl_c_used }')
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Issuer-DN  %{+Q}[ssl_c_i_dn]            if { ssl_c_used }')
          end
        end
      end
    end

    context 'when ha_proxy.forwarded_client_cert is forward_only_if_route_service' do
      let(:properties) do
        default_properties.merge({ 'forwarded_client_cert' => 'forward_only_if_route_service' })
      end

      it 'deletes mTLS headers for non-route service requests (for mTLS and non-mTLS)' do
        expect(frontend_wss).to include('acl route_service_request hdr(X-Cf-Proxy-Signature) -m found')
        expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client            if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify     if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN  if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore  if !route_service_request')
        expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter   if !route_service_request')
      end

      it 'does not add mTLS headers' do
        expect(frontend_wss).not_to include(/http-request set-header X-Forwarded-Client-Cert/)
        expect(frontend_wss).not_to include(/http-request set-header X-SSL-Client/)
      end

      context 'when mutual TLS is enabled' do
        let(:properties) do
          default_properties.merge({
            'client_cert' => true,
            'forwarded_client_cert' => 'forward_only_if_route_service'
          })
        end

        it 'deletes mTLS headers for non-route service requests (for mTLS and non-mTLS)' do
          expect(frontend_wss).to include('acl route_service_request hdr(X-Cf-Proxy-Signature) -m found')
          expect(frontend_wss).to include('http-request del-header X-Forwarded-Client-Cert if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client            if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Session-ID if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Verify     if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-DN if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Subject-CN if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-Issuer-DN  if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotBefore  if !route_service_request')
          expect(frontend_wss).to include('http-request del-header X-SSL-Client-NotAfter   if !route_service_request')
        end

        it 'overwrites mTLS headers when mTLS is used' do
          expect(frontend_wss).to include('http-request set-header X-Forwarded-Client-Cert %[ssl_c_der,base64]          if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client            %[ssl_c_used]                if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Session-ID %[ssl_fc_session_id,hex]     if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Verify     %[ssl_c_verify]              if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-NotBefore  %{+Q}[ssl_c_notbefore]       if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-NotAfter   %{+Q}[ssl_c_notafter]        if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-DN %{+Q}[ssl_c_s_dn,base64]     if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-CN %{+Q}[ssl_c_s_dn(cn),base64] if { ssl_c_used }')
          expect(frontend_wss).to include('http-request set-header X-SSL-Client-Issuer-DN  %{+Q}[ssl_c_i_dn,base64]     if { ssl_c_used }')
        end

        context 'when ha_proxy.legacy_xfcc_header_mapping is true' do
          let(:properties) do
            default_properties.merge({
              'client_cert' => true,
              'forwarded_client_cert' => 'forward_only_if_route_service',
              'legacy_xfcc_header_mapping' => true
            })
          end

          it 'overwrites mTLS headers without base64 encoding when mTLS is used' do
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-DN %{+Q}[ssl_c_s_dn]            if { ssl_c_used }')
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Subject-CN %{+Q}[ssl_c_s_dn(cn)]        if { ssl_c_used }')
            expect(frontend_wss).to include('http-request set-header X-SSL-Client-Issuer-DN  %{+Q}[ssl_c_i_dn]            if { ssl_c_used }')
          end
        end
      end
    end
  end

  context 'when ha_proxy.hsts_enable is true' do
    let(:properties) do
      default_properties.merge({ 'hsts_enable' => true })
    end

    it 'sets the Strict-Transport-Security header' do
      expect(frontend_wss).to include('http-response set-header Strict-Transport-Security max-age=31536000;')
    end

    context 'when ha_proxy.hsts_max_age is provided' do
      let(:properties) do
        default_properties.merge({ 'hsts_enable' => true, 'hsts_max_age' => 9999 })
      end

      it 'sets the Strict-Transport-Security header with the correct max-age' do
        expect(frontend_wss).to include('http-response set-header Strict-Transport-Security max-age=9999;')
      end
    end

    context 'when ha_proxy.hsts_include_subdomains is true' do
      let(:properties) do
        default_properties.merge({ 'hsts_enable' => true, 'hsts_include_subdomains' => true })
      end

      context 'when ha_proxy.hsts_enable is false' do
        let(:properties) do
          default_properties.merge({ 'hsts_enable' => false, 'hsts_include_subdomains' => true })
        end

        it 'aborts with a meaningful error message' do