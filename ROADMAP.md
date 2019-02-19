# Road map

## apache2 runit script not working properly

See: https://github.com/phusion/baseimage-docker/issues/271

## Improve healthcheck
Verify the user anonymously.
```bash
ldapsearch -h dockerhost -xLLL -b dc=circuit-factory,dc=com '(kopanoAccount=1)'
```

Check if kopano can get the user from LDAP
```bash
kopano-admin -l
```
check that apache and mysql is running
```bash
apache2ctl status
mysqlcheck -A
```
