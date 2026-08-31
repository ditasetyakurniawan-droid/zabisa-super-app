# Hotfix 0.3.5 — db-dt probe portability

The `db-dt` headless Service and EndpointSlice created by Hotfix 0.3.4 were correct: cluster DNS returned `192.168.100.70`.

The first runtime verifier nevertheless failed before reaching its TCP test because BusyBox `nslookup` can return status 1 after NXDOMAIN replies for search-suffix candidates even when a later candidate resolves successfully. With `set -e`, that status terminated the probe.

Hotfix 0.3.5 changes only the probe behavior:

- capture `nslookup` output while tolerating its process exit status;
- explicitly require an `Address: 192.168.100.70` answer;
- then test `nc -vz -w 5 db-dt 3306` using the same short hostname used by the application;
- preserve the existing Service, EndpointSlice, NetworkPolicy and application `MYSQL_HOST=db-dt` configuration.

No database credential is read or written.
