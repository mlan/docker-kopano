# 1.2.2

- [kopano](src/kopano) Adding support for gateway / imap ical search configuration via envvars in, 50-kopano-apply-envvars.
- [docker](Dockerfile) Update kopano services.

# 1.2.1

- [docker](Dockerfile) The kopano installation now (version 10.0.6) populate all example-config files in /etc/kopano. This breaks our configuration, so we need to remove them. They can still be found here /usr/share/doc/kopano/example-config.

# 1.2.0

- [docker](src/docker) Use the native envvar `SVDIR` instead of `DOCKER_RUNSV_DIR`.
- [docker](src/docker) Update docker-entrypoint.sh.
- [docker](src/docker) Update docker-service.sh.
- [docker](src/docker) Now use docker-config.sh.
- [docker](src/docker) Now use DOCKER_ENTRY_DIR=/etc/docker/entry.d and DOCKER_EXIT_DIR=/etc/docker/exit.d.
- [kopano](src/kopano) 50-kopano-apply-envvars.

# 1.1.8

- [docker](Dockerfile) Configure z-push to use HTTP_X_FORWARDED_FOR.
- [demo](demo) Made service names shorter.

# 1.1.7

- [docker](Dockerfile) Configure kopano-spamd to start with the force-remove-lingering-pid switch.
- [demo](demo) Now with 10.0.3 LDAP users get their share created, again.

# 1.1.6

- [docker](Dockerfile) Use syslogd, don't write to /var/log/apache2/other_vhosts_access.log.
- [docker](Dockerfile) No need for python to write bytecode to container. Disabling that.
- [repo](src) Separate source code in by which service it belongs to.
- [kopano](src/kopano) Configure kopano-spamd.
- [kopano](src/kopano) Workaround kopano-spamd bug: /var/lib/kopano/spamd/ham created with wrong permissions.

# 1.1.5

- [demo](demo) Use host timezone by mounting /etc/localtime.
- [demo](demo) Since 10.0.1 LDAP users don't get their share created, so `make init` now does that.

# 1.1.4

- Use `LDAP_URI` now that the historic directives `LDAP_HOST`, `LDAP_PORT`, `LDAP_PROTOCOL` are no longer supported (8.7.85).
- Split up initialization functions and process supervision. Process supervision stays in docker-entrypoint.sh, whereas the initialization functions are moved to individual files in /etc/docker/entry.d.
- Apache runit script also needs `docker-service.sh` option; force.

# 1.1.3

- The `docker-service.sh` script now have options:  down, force, log, name, source, quiet.
- Fixed the Apache runit script, using the new `docker-service.sh` script. Stopping the parent process now also stops all child processes. Using the quiet option, Apache does not flood the logs anymore.
- Added support of the environment variable `LMTP_LISTEN=*:2003`, due to misconfiguration of `kopano-dagent` in recent releases (8.7.84).
- Simplified the health check.
- Changed repository directory structure to a more general one.
- Renamed some build variables, e.g., `DOCKER_RUNSV_DIR` (was `docker_build_runit_root`).
- Cleaning up `Makefile`
- Added more debug functionality in `demo/Makefile`

# 1.1.2

- Update `Dockerfile` so that is works also for Debian 9
- Update `kopano-webaddr.sh` now that we do not have builds for Debian 8
- Updated demo

# 1.1.1

- Make sure the .env settings are honored also for MYSQL

# 1.1.0

- Reversed tag naming scheme. now `full-8.7.80-3.5.2` instead of ~~8.7.80-3.5.2-full~~
- Demo based on `docker-compose.yml` and `Makefile` files
- Check and fix file attributes in the `/var/lib/kopano/attachments` directory

# 1.0.0

- Groupware server [Kopano WebApp](https://kopano.io/)
- ActiveSync server [Z-Push](http://z-push.org/)
- Multi-staged build providing the images `full`, `debugtools` and `core`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script `conf` helping configuring Kopano components, WebApp and Z-Push
- Health check
- Hook for theming

