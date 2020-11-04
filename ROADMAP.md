# Road map

## Dockerfile

Consider removing debugtools build target. There already exists a app-debugtools target in the demo Makefile.

## kDAV

Consider integrating support for kDAV which provides CalDAV and CardDAV.

## Common configurations

The following directives exist:

```sh
!include common.cfg
```

## ACME TLS

Arrange ACME TLS certificates for kopano-gateway (IMAP POP3).

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

### Kopano Search

The kopano-search module keeps its database here, /var/lib/kopano/search.
Consider to also consolidating it under /srv to simplify making it persistent?

## webapp-passwd

Integrate [webapp-passwd](https://github.com/silentsakky/zarafa-webapp-passwd)?

## S/MIME

Install and configure [S/MIME](https://kopano.com/blog/s-mime-plugin-description/)?

[S/MIME manual](https://documentation.kopano.io/webapp_smime_manual/).

## MDM

Install and configure [MDM](https://documentation.kopano.io/webapp_mdm_manual/)?
With the MDM plugin you can resync, remove, refresh and even wipe your device.

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
