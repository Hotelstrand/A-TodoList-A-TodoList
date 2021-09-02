# Purpose of keepalived implementation

Adding support for [keepalived](http://www.keepalived.org/documentation.html) to enable high availability in an haproxy deployment, leveraging the https://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol more formally [RFC 5798](https://tools.ietf.org/html/rfc5798). See [keep-alived man page](https://linux.die.net/man/5/keepalived.conf) for more precision over capabilities of keep-alived as well as the [keep-alived user manual](http://www.keepalived.org/pdf/UserGuide.pdf)

This enables declaring an virtual IP (``keepalived.vip``) that will automatically fail over between the multiple haproxy VMs: the master will initially be the bosh vm for haproxy job instance 0. The default IP addresses assigned by bosh to vms on eth0 are used within the VRRP protocol.

Prereqs:
 * The haproxy VMs must be within the same broadcast domain, i.e. receive multicast traffic sent to the 224.0.0.18 broadcast and IP protocol number 112.
* The clients using this VIP must be within the [same broadcast domain](https://en.wikipedia.org/wiki/Broadcast_domain) a