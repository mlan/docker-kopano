# Road map

## Logs

kopano-spamd and kopano-search does not use syslog. Try to fix.

## kDAV

Consider integrating support for kDAV which provides CalDAV and CardDAV.

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

### Kopano Search

The kopano-search module keeps its database here, /var/lib/kopano/search.
Consider to also consolidating it under /srv to simplify making it persistent?

## webapp-passwd

Integrate [webapp-passwd](https://github.com/silentsakky/zarafa-webapp-passwd)?
