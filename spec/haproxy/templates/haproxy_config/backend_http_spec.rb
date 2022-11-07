
# frozen_string_literal: true

require 'rspec'

describe 'config/haproxy.config backend http-routers' do
  let(:haproxy_conf) do
    parse_haproxy_config(template.render({ 'ha_proxy' => properties }))
  end

  let(:properties) { {} }
  let(:backend_http1) { haproxy_conf['backend http-routers-http1'] }
  let(:backend_http2) { haproxy_conf['backend http-routers-http2'] }

  it 'has the correct mode' do
    expect(backend_http1).to include('mode http')
  end

  it 'uses round-robin load balancing' do
    expect(backend_http1).to include('balance roundrobin')
  end

  context 'when ha_proxy.compress_types are provided' do
    let(:properties) { { 'compress_types' => 'text/html text/plain text/css' } }

    it 'configures the compression type and algorithm' do
      expect(backend_http1).to include('compression algo gzip')
      expect(backend_http1).to include('compression type text/html text/plain text/css')
    end
  end

  context 'when ha_proxy.backend_config is provided' do
    let(:properties) do
      {
        'backend_config' => 'custom backend config'
      }
    end

    it 'includes the config' do
      expect(backend_http1).to include('custom backend config')
    end
  end

  context 'when ha_proxy.custom_http_error_files is provided' do
    let(:properties) do
      {
        'custom_http_error_files' => {
          '503' => '<html><body><h1>503 Service Unavailable</h1></body></html>'
        }
      }
    end

    it 'includes the errorfiles' do
      expect(backend_http1).to include('errorfile 503 /var/vcap/jobs/haproxy/errorfiles/custom503.http')
    end
  end

  context 'when ha_proxy.backend_use_http_health is true' do
    let(:properties) do
      {
        'backend_use_http_health' => true,
        'backend_servers' => ['10.0.0.1', '10.0.0.2']
      }
    end

    it 'configures the healthcheck' do
      expect(backend_http1).to include('option httpchk GET /health')
    end

    it 'adds the healthcheck to the server config' do
      expect(backend_http1).to include('server node0 10.0.0.1:80 check inter 1000 port 8080 fall 3 rise 2')
      expect(backend_http1).to include('server node1 10.0.0.2:80 check inter 1000 port 8080 fall 3 rise 2')
    end

    context 'when backend_http_health_uri is provided' do
      let(:properties) do
        {
          'backend_use_http_health' => true,
          'backend_http_health_uri' => '1.2.3.5/health',
          'backend_servers' => ['10.0.0.1', '10.0.0.2']
        }
      end

      it 'configures the healthcheck' do
        expect(backend_http1).to include('option httpchk GET 1.2.3.5/health')
      end

      it 'adds the healthcheck to the server config' do
        expect(backend_http1).to include('server node0 10.0.0.1:80 check inter 1000 port 8080 fall 3 rise 2')
        expect(backend_http1).to include('server node1 10.0.0.2:80 check inter 1000 port 8080 fall 3 rise 2')
      end
    end

    context 'when backend_http_health_port is provided' do
      let(:properties) do
        {
          'backend_use_http_health' => true,
          'backend_http_health_port' => 8081,
          'backend_servers' => ['10.0.0.1', '10.0.0.2']
        }
      end

      it 'configures the healthcheck' do
        expect(backend_http1).to include('option httpchk GET /health')
      end

      it 'adds the healthcheck to the server config' do
        expect(backend_http1).to include('server node0 10.0.0.1:80 check inter 1000 port 8081 fall 3 rise 2')
        expect(backend_http1).to include('server node1 10.0.0.2:80 check inter 1000 port 8081 fall 3 rise 2')
      end
    end

    context 'when backend_health_fall is provided' do
      let(:properties) do
        {
          'backend_use_http_health' => true,
          'backend_servers' => ['10.0.0.1', '10.0.0.2'],
          'backend_health_fall' => 42
        }
      end

      it 'configures the healthcheck' do
        expect(backend_http1).to include('option httpchk GET /health')
      end

      it 'configures the servers' do
        expect(backend_http1).to include('server node0 10.0.0.1:80 check inter 1000 port 8080 fall 42 rise 2')
        expect(backend_http1).to include('server node1 10.0.0.2:80 check inter 1000 port 8080 fall 42 rise 2')
      end
    end

    context 'when backend_health_rise is provided' do
      let(:properties) do
        {
          'backend_use_http_health' => true,
          'backend_servers' => ['10.0.0.1', '10.0.0.2'],
          'backend_health_rise' => 99
        }
      end

      it 'configures the healthcheck' do
        expect(backend_http1).to include('option httpchk GET /health')
      end

      it 'configures the servers' do
        expect(backend_http1).to include('server node0 10.0.0.1:80 check inter 1000 port 8080 fall 3 rise 99')
        expect(backend_http1).to include('server node1 10.0.0.2:80 check inter 1000 port 8080 fall 3 rise 99')
      end
    end
  end