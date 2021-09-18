[haproxy-boshrelease][1] has two different features related to Mutual TLS -
[authenticating itself][2] with a set of backend servers, and [passing through][3]
end-user client certificates to backend apps. Both features can be used
on their own, or in tandem, depending on the requirements of the infrastructure
deployed.

## Using HAProxy in front of Backends that require Mutual TLS

If HAProxy is placed in front of backend servers that require
Client SSL Certificates/Mutual TLS, you will want to ensure the
following property is set:

```
properties:
  haproxy:
    backend_crt: |
      ----- BEGIN CERTIFICATE -----
      YOUR CERT PEM HERE
      ----- END CERTIFICATE -----
      ----- BEGIN RSA PRIVATE KEY -----
      YOUR KEY HERE
      ----- END RSA PRIVATE KEY -----
```

If you wish to have HAProxy perform SSL verification on the backend
it's connecting to, add the following properties to the mix:

```
properties:
  haproxy:
    backend_ssl: verify
    backend_ca: |
      ----- BEGIN CERTIFICATE -----
      CA Certificate for validating backend certs
      ----- END CERTIFICATE -----
    backend_ssl_verifyhost: # Omit these if you only want to validate that the CA signed the backend
    - backend-host.com      # server's cert, and not check hostnames + certificate Subjects
```

## Configuring HAProxy to Pass Client Certificates to Apps

HAProxy can be configured to pass client certificates on to apps requiring them on the backend.
This does not enforce mutual TLS at the HAP