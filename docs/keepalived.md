# Purpose of keepalived implementation

Adding support for [keepalived](http://www.keepalived.org/documentation.html) to enable high availability in an haproxy deployment, leveraging the https://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol more formally [RFC 5798](https://tools.ietf.org/html/rfc5798). See [keep-alived man page](https://linux.die.net/man/5/keepalived.conf) for more precision over capabilities of keep-alived as well as the [keep-alived user manual](http://www.keepalived.org/pdf/UserGuide.pdf)

This enables declaring an virtual IP (``keepalived.vip``) that will automatically fail over between the multiple hapr