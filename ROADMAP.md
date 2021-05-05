# Road map

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

- /etc/kopano
- /var/lib/kopano
- /var/lib/z-push

### Kopano Search

The kopano-search module keeps its database here, /var/lib/kopano/search.
Consider to also consolidating it under /srv to simplify making it persistent?

## kDAV

Consider integrating support for kDAV which provides CalDAV and CardDAV.

## webapp-passwd

Integrate [webapp-passwd](https://github.com/silentsakky/zarafa-webapp-passwd)?

## kopano-spamd and kopano-search logs

In [KC-1858](https://github.com/Kopano-dev/kopano-core/commit/4a7f833e170167ebfa4f4c55835f8760ce7617f3) we find:

> The syslog log method does not work correctly and thus this change
> disables it. Until it is fixed, Python services do not support
> the syslog log_method. Additionally an environment variable is
> added, which allow to lift this restriction for testing when it
> it set.

