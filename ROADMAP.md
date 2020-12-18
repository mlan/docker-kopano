# Road map

## Overlapping parameters

`MYSQL_HOST=db`
`SERVER_MYSQL_HOST=db-srv`
`ARCHIVER_MYSQL_HOST=db-arc`

## Cron

`CRONTAB_ENTRY1=0 1 * * * root kopano-archiver -A`
`CRONTAB_ENTRY2=0 3 * * 0 root kopano-archiver -C`

## kDAV

Consider integrating support for kDAV which provides CalDAV and CardDAV.

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

### Kopano Search

The kopano-search module keeps its database here, /var/lib/kopano/search.
Consider to also consolidating it under /srv to simplify making it persistent?

## webapp-passwd

Integrate [webapp-passwd](https://github.com/silentsakky/zarafa-webapp-passwd)?
