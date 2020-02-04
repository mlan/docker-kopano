# Road map

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

### Kopano Search

The kopano-search module keeps its database here, /var/lib/kopano/search.
Consider to also consolidating it under /srv to simplify making it persistent?

## Improve Health Check?

Verify the user anonymously.
```bash
ldapsearch -h dockerhost -xLLL -b dc=example,dc=com '(kopanoAccount=1)'
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
