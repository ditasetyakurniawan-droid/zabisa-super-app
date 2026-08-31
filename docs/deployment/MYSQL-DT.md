# DT MySQL contract

- Host VM: `192.168.100.70`
- Docker container: `mysql-db`
- MySQL: 8.0.x
- Kubernetes DNS abstraction: `db-dt.zabisa-app.svc.cluster.local`
- Port: `3306`
- Zabisa uses client-enforced TLS `verify-ca` with a pinned CA.

Databases:

| Service | Database | Runtime KV | Migrator KV |
| --- | --- | --- | --- |
| identity | `identity_db` | `kv/zabisa/dt/identity/database` | `kv/zabisa/dt/identity/migrator` |
| content | `content_db` | `kv/zabisa/dt/content/database` | `kv/zabisa/dt/content/migrator` |
| student | `student_db` | `kv/zabisa/dt/student/database` | `kv/zabisa/dt/student/migrator` |
| tahfidz | `tahfidz_db` | `kv/zabisa/dt/tahfidz/database` | `kv/zabisa/dt/tahfidz/migrator` |
| academic | `academic_db` | `kv/zabisa/dt/academic/database` | `kv/zabisa/dt/academic/migrator` |
| donation | `donation_db` | `kv/zabisa/dt/donation/database` | `kv/zabisa/dt/donation/migrator` |
| notification | `notification_db` | `kv/zabisa/dt/notification/database` | `kv/zabisa/dt/notification/migrator` |

Do not reuse existing `tropical`, `tropicalos`, `root`, or unrelated application databases/users.
