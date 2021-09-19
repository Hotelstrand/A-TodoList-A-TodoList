
# Client IP based Rate Limiting
Rate limits in HAProxy are based on stick-tables. The concept of stick-tables is explained in [this blog article](https://www.haproxy.com/blog/introduction-to-haproxy-stick-tables/). It covers all relevant parts and gives a general idea on how one could rate limit based on certain attributes.

HAProxy-boshrelease can be configured to enforce these rate limits based on requests and connections per second per IP.