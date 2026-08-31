# Hotfix 0.3.4 — db-dt Kubernetes DNS abstraction

The DT MySQL 8 server runs inside Docker Compose on VM `192.168.100.70` and publishes host TCP/3306.
A direct pod probe proved `192.168.100.70:3306` reachable, while `db-dt` returned NXDOMAIN.

This hotfix adds a selectorless **headless Service** named `db-dt` plus a manually managed `EndpointSlice` for `192.168.100.70:3306`.
The headless form is deliberate: Kubernetes DNS returns the external endpoint IP directly, avoiding Service DNAT and preserving the existing Calico `ipBlock: 192.168.100.70/32` control.

No DB credential is included. Seven stateful bounded contexts keep `MYSQL_HOST=db-dt`; API gateway remains DB-free.
