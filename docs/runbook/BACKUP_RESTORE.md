# MySQL backup and restore

Enable MySQL binary logs with retention aligned to RPO, take encrypted full backups, and copy them to storage independent of db-dt. Perform scheduled restore drills into an isolated database. Record backup timestamp, binlog coordinates, restore duration, checksum/row-count validation and operator. A backup is not considered valid until restoration is tested.
