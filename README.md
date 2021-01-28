# The `mlan/kopano` repository

![travis-ci test](https://img.shields.io/travis/mlan/docker-kopano.svg?label=build&style=popout-square&logo=travis)
![docker build](https://img.shields.io/docker/cloud/build/mlan/kopano.svg?label=build&style=popout-square&logo=docker)
![image Size](https://img.shields.io/docker/image-size/mlan/kopano.svg?label=size&style=popout-square&logo=docker)
![docker pulls](https://img.shields.io/docker/pulls/mlan/kopano.svg?label=pulls&style=popout-square&logo=docker)
![docker stars](https://img.shields.io/docker/stars/mlan/kopano.svg?label=stars&style=popout-square&logo=docker)
![github stars](https://img.shields.io/github/stars/mlan/docker-kopano.svg?label=stars&style=popout-square&logo=github)

This (non official) repository provides dockerized web mail service as well as Exchange ActiveSync (EAS), IMAP, POP3 and ICAL service (and their secure variants IMAPS, POP3S and ICALS). It is based on [Kopano](https://kopano.com) core components, as well as the Kopano WebApp and [Z-Push](http://z-push.org/). The image uses [nightly built packages](https://download.kopano.io/community/) which are provided by the Kopano community.

Hopefully this repository can be retired once the Kopano community make official images available. To learn more about this activity see [zokradonh/kopano-docker](https://github.com/zokradonh/kopano-docker).

## Features

- [Kopano WebApp](https://kopano.io/) the main client to access all the features provided by Kopano core
- [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync) server [Z-Push](http://z-push.org/)
- IMAP, POP3 and ICAL services provided by Kopano core
- Secure protocols IMAPS, POP3S and ICALS
- Hooks for integrating [Let’s Encrypt](https://letsencrypt.org/) LTS certificates using the reverse proxy [Traefik](https://docs.traefik.io/)
- Multi-staged build providing the images `full` and `core`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script [run](src/docker/bin/run) helping configuring Kopano components, WebApp and Z-Push
- [Move to public with LDAP lookup](#move-to-public-with-ldap-lookup)
- [Crontab](https://en.wikipedia.org/wiki/Cron) support.
- Health check
- Hook for theming
- Demo based on `docker-compose.yml` and `Makefile` files

## Tags

The `mlan/kopano` repository contains a multi staged built. You select which build using the appropriate tag.

The version part of the tag is not based on the version of this repository. It is instead, based on the combined revision numbers of the nightly Kopano core and Kopano WebApp package suits that was available when building the images. For example, `8.7.80-3.5.2` indicates that the image was built using the 8.7.80 version of Kopano core and 3.5.2 version of Kopano WebApp.

The build part of the tag is one of `full` and `core`. The image with tag `full` contain Kopano core components, as well as, the Kopano WebApp and Z-Push. The image with tag `core` contains the Kopano core components proving the server and IMAP, POP3 and ICAL access, but no web access.

The tags `latest`, `full`, or `core` all reference the most recent builds.

To exemplify the usage of the tags, lets assume that the latest version tag is `8.7.80-3.5.2`. In this case `latest`, `8.7.80-3.5.2`, `full`, and `full-8.7.80-3.5.2` all identify the same image.

# Usage

In most use cases the `mlan/kopano` container also needs a SQL database (e.g., [MySQL](https://hub.docker.com/_/mysql) or [MariaDB](https://hub.docker.com/_/mariadb)), Mail Transfer Agent (e.g., [Postfix](http://www.postfix.org/)) and authentication (e.g., [OpenLDAP](https://www.openldap.org/)). Docker images of such services are available.

Often you want to configure Kopano and its components. There are
different methods available to achieve this. You can use the environment
variables described below set in the shell before creating the container.
These environment variables can also be explicitly given on
the command line when creating the container. They can also be given in
an `docker-compose.yml` file (and the `.env` file), see below. Moreover docker
volumes or host directories with desired configuration files can be
mounted in the container. And finally you can exec into a running container and modify configuration files directly.

The docker compose example below is used to demonstrate how to configure these services.

## Docker compose example

An example of how to configure an web mail server using docker compose is given below. It defines 4 services, `app`, `mta`, `db` and `auth`, which are the web mail server, the mail transfer agent, the SQL database and LDAP authentication respectively.

```yaml
version: '3'

services:
  app:
    image: mlan/kopano
    networks:
      - backend
    ports:           # Expose ports to host interfaces
      - "80:80"      # WebApp & EAS (alt. HTTP)
      - "143:143"    # IMAP (not needed if all devices can use EAS)
      - "110:110"    # POP3 (not needed if all devices can use EAS)
      - "8080:8080"  # ICAL (not needed if all devices can use EAS)
      - "993:993"    # IMAPS (not needed if all devices can use EAS)
      - "995:995"    # POP3S (not needed if all devices can use EAS)
      - "8443:8443"  # ICALS (not needed if all devices can use EAS)
    depends_on:
      - auth
      - db
      - mta
    environment: # Virgin config, ignored on restarts unless FORCE_CONFIG given.
      - USER_PLUGIN=ldap
      - LDAP_URI=ldap://auth:389/
      - MYSQL_HOST=db
      - SMTP_SERVER=mta
      - LDAP_SEARCH_BASE=${AD_BASE-dc=example,dc=com}
      - LDAP_USER_TYPE_ATTRIBUTE_VALUE=${AD_USR_OB-kopano-user}
      - LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=${AD_GRP_OB-kopano-group}
      - LDAP_GROUPMEMBERS_ATTRIBUTE_TYPE=dn
      - LDAP_PROPMAP=
      - DAGENT_PLUGINS=movetopublicldap
      - MYSQL_DATABASE=${MYSQL_DATABASE-kopano}
      - MYSQL_USER=${MYSQL_USER-kopano}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD-secret}
      - IMAP_LISTEN=*:143                       # also listen to eth0
      - POP3_LISTEN=*:110                       # also listen to eth0
      - ICAL_LISTEN=*:8080                      # also listen to eth0
      - IMAPS_LISTEN=*:993                      # enable TLS
      - POP3S_LISTEN=*:995                      # enable TLS
      - ICALS_LISTEN=*:8443                     # enable TLS
      - PLUGIN_SMIME_USER_DEFAULT_ENABLE_SMIME=true
      - SYSLOG_LEVEL=${SYSLOG_LEVEL-3}
      - LOG_LEVEL=${LOG_LEVEL-3}
    volumes:
      - app-conf:/etc/kopano
      - app-atch:/var/lib/kopano/attachments
      - app-sync:/var/lib/z-push
      - app-spam:/var/lib/kopano/spamd          # kopano-spamd integration
      - /etc/localtime:/etc/localtime:ro        # Use host timezone
    cap_add: # helps debugging by allowing strace
      - sys_ptrace

  mta:
    image: mlan/postfix-amavis
    hostname: ${MAIL_SRV-mx}.${MAIL_DOMAIN-example.com}
    networks:
      - backend
    ports:           # Expose ports to host interfaces
      - "25:25"      # SMTP
      - "465:465"    # SMTPS authentication required
    depends_on:
      - auth
    environment: # Virgin config, ignored on restarts unless FORCE_CONFIG given.
      - LDAP_HOST=auth
      - VIRTUAL_TRANSPORT=lmtp:app:2003
      - LDAP_USER_BASE=ou=${AD_USR_OU-users},${AD_BASE-dc=example,dc=com}
      - LDAP_QUERY_FILTER_USER=(&(objectclass=${AD_USR_OB-kopano-user})(mail=%s))
    volumes:
      - mta:/srv
      - app-spam:/var/lib/kopano/spamd          # kopano-spamd integration
      - /etc/localtime:/etc/localtime:ro        # Use host timezone
    cap_add: # helps debugging by allowing strace
      - sys_ptrace

  db:
    image: mariadb
    command: ['--log_warnings=1']
    networks:
      - backend
    environment:
      - LANG=C.UTF-8
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD-secret}
      - MYSQL_DATABASE=${MYSQL_DATABASE-kopano}
      - MYSQL_USER=${MYSQL_USER-kopano}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD-secret}
    volumes:
      - db:/var/lib/mysql
      - /etc/localtime:/etc/localtime:ro        # Use host timezone

  auth:
    image: mlan/openldap
    networks:
      - backend
    command: --root-cn ${AD_ROOT_CN-admin} --root-pw ${AD_ROOT_PW-secret}
    environment:
      - LDAPBASE=${AD_BASE-dc=example,dc=com}
      - LDAPDEBUG=${AD_DEBUG-parse}
    volumes:
      - auth:/srv
      - /etc/localtime:/etc/localtime:ro        # Use host timezone

networks:
  backend:

volumes:
  app-atch:
  app-conf:
  app-spam:
  app-sync:
  auth:
  db:
  mta:
```

## Demo

This repository contains a [demo](demo) directory which hold the [docker-compose.yml](demo/docker-compose.yml) file as well as a [Makefile](demo/Makefile) which might come handy. To run the demo you need [docker-compose](https://docs.docker.com/compose/install/) installed. By default `curl` and `firefox` is expected to be installed, but if not, run `make utils-container` within the [demo](demo) directory once the repository has been cloned. The `make` utility works nicely with [bash-completion](https://github.com/scop/bash-completion) so it can be worth considering having it installed too. Once the dependencies are met, start with cloning the [github](https://github.com/mlan/docker-kopano) repository.

```bash
git clone https://github.com/mlan/docker-kopano.git
```

From within the [demo](demo) directory you can start the containers by typing:

```bash
make init
```

Now you can assess WebApp on the custom docker network at URL `http://app` and log in with the user name `demo` and password `demo`.

```bash
make web
```

You can send yourself a test email by typing:

```bash
make test
```

When you are done testing you can destroy the test containers and their volumes by typing:

```bash
make destroy
```

## Persistent storage

By default, docker will store the user data and service configurations within the container. This has the drawback that the user data and service configurations are lost together with the container should it be deleted. It can therefore be a good idea to use docker volumes and mount the run directories and/or the configuration directories there so that the data will survive a container deletion.

There are at least three directories which should be considered for persistent storage; the configuration files, `/etc/kopano`, the mail attachments, if they are kept in files, `/var/lib/kopano/attachments` and the active sync device states, if they are kept in files, `/var/lib/z-push`.

## Configuration / seeding procedure

The `mlan/kopano` image contains an elaborate configuration / seeding procedure. The configuration is controlled by environment variables, described below.

The seeding procedure will leave any existing configuration untouched. This is achieved by the using an unlock file: `DOCKER_UNLOCK_FILE=/etc/kopano/.docker.unlock`.
During the image build this file is created. When the the container is started the configuration / seeding procedure will be executed if the `DOCKER_UNLOCK_FILE` can be found. Once the procedure completes the unlock file is deleted preventing the configuration / seeding procedure to run when the container is restarted.

The unlock file approach was selected since it is difficult to accidentally _create_ a file.

In the rare event that want to modify the configuration of an existing container you can override the default behavior by setting `FORCE_CONFIG=overwrite` to a no-empty string.

## Environment variables and service parameters

When you create the `mlan/kopano` container, you can adjust the configuration of the Kopano server by defining one or more environment variables. During container initiation environment variables are matched against all possible parameters for all Kopano services. When matched, configuration files are updated with the value of the matching environment variable.

To see all available configuration parameters you can run `run list_parms <service>` within the container or when when using the [demo](#demo) described above just type:

```bash
make app-parms_dagent
make app-parms_server
```

### Overlapping parameter names

Some services use the same parameter names. When such a parameter is set using en environment variable all configuration files of the related services will be updated. This is not always desired. To address this you can prefix the parameter name with the name of the service you which to target by using the following syntax: `<service>_<parameter>`.

For example when using the [Kopano-archiver](https://documentation.kopano.io/kopano_archiver_manual/) service, you often want to use one SQL database for the server and one separate one for the archiver. In this situation you can have two separate SQL database containers, one at `db-srv` and the other at `db-arc`. To set the [`MYSQL_HOST`](#mysql_host) parameter in the two relevant configuration files use `SERVER_MYSQL_HOST=db-srv` and `ARCHIVER_MYSQL_HOST=db-arc`. If for some reason you want both services to call the same container, instead use: `MYSQL_HOST=db`.

## SQL database configuration

The Kopano server uses a SQL database, which needs to be initiated, see below. Once the SQL database has been initiated you can create the Kopano container and configure it to use the SQL database using environment variables.

#### `MYSQL_HOST`

The host name of the MySQL server to use. Default `MYSQL_HOST=localhost`.

#### `MYSQL_PORT`

The port of the MySQL server to use. Default `MYSQL_PORT=3306`

#### `MYSQL_USER`

The user under which we connect with MySQL. Default `MYSQL_USER=root`. For security reasons it is probably wise not to use the `root` user. Use the same name as was used when initiating the SQL database, see below.

#### `MYSQL_PASSWORD`

The password to use for MySQL. It is possible to leave it empty for no password, but that is advised against. Default `MYSQL_PASSWORD=`. Use the same password as was used when initiating the SQL database, see below.

#### `MYSQL_DATABASE`

The MySQL database to connect to. Default `MYSQL_DATABASE=kopano`. Use the same database name as was used when initiating the SQL database, see below.

#### `ATTACHMENT_STORAGE`

The location where attachments are stored. This can be in the MySQL database, or as separate files. The drawback of `database` is that the large data of attachment will push useful data from the MySQL cache. The drawback of separate files is that a `mysqldump` is not enough for a full disaster recovery. Possible values: `database`, `files`, `files_v2` (experimental). Default: `ATTACHMENT_STORAGE=files`

#### `ATTACHMENT_COMPRESSION`

When the `ATTACHMENT_STORAGE` option is `ATTACHMENT_STORAGE=files`, this option controls the compression level for the attachments. Higher compression levels will compress data better, but at the cost of CPU usage. Lower compression levels will require less CPU but will compress data less. Setting the compression level to 0 will effectively disable compression completely. Changing the compression level, or switching it on or off, will not affect any existing attachments, and will remain accessible as normal. Set to 0 to disable compression completely. The maximum compression level is 9. Default: `ATTACHMENT_COMPRESSION=6`

### SQL Database initialization

When creating the SQL container you can use environment variables to initiate it. For example, `MYSQL_ROOT_PASSWORD=topsecret`, `MYSQL_DATABASE=kopano`, `MYSQL_USER=kopano` and `MYSQL_PASSWORD=verysecret`.

## User management `USER_PLUGIN`

Kopano supports three different plugins for user management. Use the `USER_PLUGIN` environment variable to select the source of the user base. Possible values are: `db` (default), `ldap` and `unix`.

`db`: Retrieve the users from the Kopano database. Use the `kopano-admin` tool to create users and groups. There are no additional settings for this plug-in.

`ldap`: Retrieve the users and groups information from an LDAP directory server. Additional LDAP settings are needed, see below.

`unix`: Retrieve the users and groups information from the Linux password files. This option is probably not interesting here.

### Accessing an LDAP directory server

The `USER_PLUGIN=ldap` retrieves user information from an LDAP directory server. A brief description of how that is achieved is described in [Setup an LDAP directory server](#setup-an-ldap-directory-server). Once the LDAP directory server is up and running, the `mlan/kopano` container can be configured to use it using environment variables.

#### Host address `LDAP_URI`

Specifies the URI of one or more LDAP server(s) to use, without any DN portion, such as `ldap://server:389/`, `ldaps://server:636/` or `ldapi:///`. Defaults: `LDAP_URI=ldap://localhost:389/`.

Note that. the historic directives `LDAP_HOST`, `LDAP_PORT`, `LDAP_PROTOCOL` are no longer supported (8.7.85).

#### `LDAP_SEARCH_BASE`

This is the subtree entry where all objects are defined in the LDAP server. Default: `LDAP_SEARCH_BASE=dc=kopano,dc=com`

#### `LDAP_USER_TYPE_ATTRIBUTE_VALUE`

This variable determines what defines a valid Kopano user. Default: `LDAP_USER_TYPE_ATTRIBUTE_VALUE=posixAccount`

#### `LDAP_GROUP_TYPE_ATTRIBUTE_VALUE`

This variable determines what defines a valid Kopano group. Default: `LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=posixGroup`

#### `LDAP_USER_SEARCH_FILTER`

Adds an extra filter to the user search. Default `LDAP_USER_SEARCH_FILTER=`

Hint: Use the `kopanoAccount` attribute in the filter to differentiate between non-Kopano and Kopano users.

#### `LDAP_BIND_USER`, `LDAP_BIND_PASSWD`

The defaults for these environment variables are empty. If you cannot bind anonymously, do it with this distinguished name and password. Example: LDAP_BIND_USER=cn=admin,dc=example,dc=com, LDAP_BIND_PASSWD=secret.

### Kopano LDAP attributes `LDAP_PROPMAP`

The Kopano services needs to know which of the users LDAP attributes, like addresses, phone numbers and company information, to use. This information is defined in the `propmap` file, which is included in the Kopano installation files here `/usr/share/kopano/ldap.propmap.cfg`. When using `USER_PLUGIN=ldap` this LDAP `propmap` file is used by the Kopano services by setting `LDAP_PROPMAP=` to an empty string. Optionally you can use another file, for example`LDAP_PROPMAP=/etc/kopano/ldap.propmap.cfg`. If no file can be found there the installed one will be copied there.

## Enabling IMAP, POP3 and ICAL

By default the [IMAP](https://www.atmail.com/blog/imap-commands/) and POP3 services are disabled for all users. Set the environment variable `DISABLED_FEATURES=` to an empty string to enable both IMAP and POP3 for all users. You can override this setting for each user independently by enabling or disabling features in the LDAP directory server see, [Setup an LDAP directory server](#setup-an-ldap-directory-server).

#### `DISABLED_FEATURES`

The environment variable `DISABLED_FEATURES` take a space separated list of features. Currently it may contain the following features: `imap`, `mobile`, `outlook`, `pop3` and `webapp`. Default: `DISABLED_FEATURES="imap pop3"`

#### `IMAP_LISTEN`, `POP3_LISTEN`and `ICAL_LISTEN`

By default the kopano-gateway and kopano-ical services are configured to only listen on the loop-back interface. To be able to access these services we need them to listen to any interface. This is achieved by setting `IMAP_LISTEN=*:143`, `POP3_LISTEN=*:110` and `ICAL_LISTEN=*:8080`. These port numbers can be changed if desired.

## Enabling IMAPS, POP3S and ICALS

By default the secure protocols are not enabled.

#### `IMAPS_LISTEN`, `POP3S_LISTEN`and `ICALS_LISTEN`

To enable secure access we need to explicitly define their listening ports. This is achieved by setting any combination of `IMAPS_LISTEN=*:993`, `POP3S_LISTEN=*:995` and `ICALS_LISTEN=*:8443`. These port numbers can be changed if desired.

If any of `IMAPS_LISTEN`, `POP3S_LISTEN` and `ICALS_LISTEN` are explicitly defined but there are no certificate files defined, a self-signed certificate will be generated when the container is created.

### SSL/LTS certificate and private key

For most deployments a trusted SSL/TLS certificate is desired. During startup the `mlan/kopano` looks for [RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem)) [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) certificate and private key with these specific names: `/etc/kopano/ssl/cert.pem` and `/etc/kopano/ssl/priv_key.pem`. If found they will used by the secure protocols IMAPS, POP3S and ICALS. Moreover the file ownership will be changed if needed to make them readable by the Kopano services.

#### `SSL_CERTIFICATE_FILE` and `SSL_PRIVATE_KEY_FILE`

If you use other file names or directories, you let the Kopano services know by setting the variables `SSL_CERTIFICATE_FILE=/etc/kopano/ssl/cert.pem` and `SSL_PRIVATE_KEY_FILE=/etc/kopano/ssl/priv_key.pem` on the `docker run` command line or in the `docker-compose.yml` file.

For testing purposes you can create a self-signed certificate using the `openssl` utility, see below. Note that this is not necessary since, when secure protocols are defined, a self-signed certificate and private key will be automatically be created during container startup if they are not found.

```bash
openssl genrsa -out ssl/priv_key.pem
openssl req -x509 -utf8 -new -batch -subj "/CN=app" -key ssl/priv_key.pem -out ssl/cert.pem
```

One way to allow the container to read the certificate and private key is to bind mount the host directory holding the files to the container:

```bash
docker run -d -name app -v $pwd/ssl:/etc/kopano/ssl mlan/kopano
```

A other way is to copy them to the container:

```bash
docker create -name app mlan/kopano
docker cp ssl/. app:/etc/kopano/ssl
docker start app
```

If you copy the files to a running container you need to make sure that the user `kopano` can read them.

### Let’s Encrypt LTS certificates using [Traefik](https://docs.traefik.io/)

[Let’s Encrypt](https://letsencrypt.org/) provide free, automated, authorized certificates when you can demonstrate control over your domain. [Automatic Certificate Management Environment (ACME)](https://en.wikipedia.org/wiki/Automated_Certificate_Management_Environment) is the protocol used for such demonstration. There are many agents and applications that supports ACME, e.g., [certbot](https://certbot.eff.org/). The reverse proxy [Traefik](https://docs.traefik.io/) also supports ACME.

#### `ACME_FILE`, `ACME_POSTHOOK`

The `mlan/kopano` image looks for a file `ACME_FILE=/acme/acme.json` at container startup and every time this file changes certificates within this file are extracted. If the host or domain name of one of those certificates matches `HOSTNAME=$(hostname)` or `DOMAIN=${HOSTNAME#*.}` it will be used by the secure protocols.

Once the certificates and keys have been updated, we run the command in the environment variable `ACME_POSTHOOK="sv restart kopano-gateway kopano-ical"`. Kopano services needs to be restarted to update the LTS parameters. If such automatic reloading is not desired, set `ACME_POSTHOOK=` to empty.

So reusing certificates from Traefik will work out of the box if the `/acme` directory in the Traefik container is also mounted in the `mlan/kopano` container.

```bash
docker run -d -name proxy -v proxy-acme:/acme traefik
docker run -d -name app -v proxy-acme:/acme:ro mlan/kopano
```

Note, if the target certificate Common Name (CN) or Subject Alternate Name (SAN) is changed the container needs to be restarted.

Moreover, do not set any of `SSL_CERTIFICATE_FILE` and `SSL_PRIVATE_KEY_FILE` when using `ACME_FILE`.

## Logging `SYSLOG_LEVEL`, `LOG_LEVEL`

The level of output for logging is in the range from 0 to 7. The default is: `SYSLOG_LEVEL=5`.

| emerg | alert | crit | err  | warning | notice | info | debug |
| ----- | ----- | ---- | ---- | ------- | ------ | ---- | ----- |
| 0     | 1     | 2    | 3    | 4       | **5**  | 6    | 7     |

Separately, `LOG_LEVEL` controls the logging level of the Kopano services. `LOG_LEVEL` takes valued from 0 to 6, where the default is `LOG_LEVEL=3`.

| none | crit | err  | warning | notice | info | debug |
| ---- | ---- | ---- | ------- | ------ | ---- | ----- |
| 0    | 1    | 2    | **3**   | 4      | 5    | 6     |

## Kopano add-ons

### Kopano Archiver

The [Kopano Archiver](https://documentation.kopano.io/kopano_archiver_manual/) provides a Hierarchical Storage Management (HSM) solution for Kopano. With the Kopano Archiver older messages will be automatically moved to slower and thus cheaper storage. The slow storage consists of one or more additional Kopano Archive servers which sole task it is to store archived messages.

Typically the archiver needs its own SQL database. You can configure it using environment variables. When you do, pay attention to [overlapping parameter names](#overlapping-parameter-names). Also the archiver does not run as a daemon but instead you can set up [cron](#cron) jobs. For example, to run the archiver daily with weakly clean-up you can use; `CRONTAB_ENTRY1=0 1 * * * root kopano-archiver -A` and `CRONTAB_ENTRY2=0 3 * * 0 root kopano-archiver -C`.

## WebApp custom themes

You can easily customize the Kopano WebApp see [New! JSON themes in Kopano WebApp](https://kopano.com/blog/new-json-themes-in-kopano-webapp/). Once you have the files you can install them in your docker container using the receipt below, where we assume that the container name is `mail-app` and that the directory `mytheme` contains the `theme.json` and the other file defining the theme.

```bash
docker cp mytheme/. mail-app:/etc/kopano/theme/Custom
docker exec -it mail-app chown -R root: /etc/kopano/theme
docker exec -it mail-app run dc_replace /etc/kopano/webapp/config.php 'define("THEME", \x27\x27);' 'define("THEME", \x27Custom\x27);'
```

Please note that it is not possible to rename the directory `/etc/kopano/theme/Custom` within the container without further modifications.

## WebApp plugins

### S/MIME

[S/MIME](https://en.wikipedia.org/wiki/S/MIME) provides [email encryption](https://en.wikipedia.org/wiki/Email_encryption) guaranteeing the confidentiality and non-repudiation of email. The [S/MIME](https://documentation.kopano.io/webapp_smime_manual/) WebApp plugin is pre-installed.

Using the [demo](#demo) you can easily create a S/MIME certificate you can try out using WebApp.

```sh
make app-create_smime
```

### Mobile device management

The [Mobile Device Management](https://documentation.kopano.io/webapp_mdm_manual/) WebApp plugin comes pre-installed. With it you can resync, remove, refresh and even wipe your devices, connected via [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync).

## Public folders

There are two type of stores (folders containing communication elements); private and public stores. There can only be one public store. It is the Kopano dagent that places incoming messages into mail boxes, that is the private and public stores.

Public folders are configured by the system admin. Users have them mapped automatically. The shared and public folders can be synced with mobile devices via [Exchange ActiveSync (EAS)](https://wiki.z-hub.io/display/ZP/Sharing+folders+and+Read-only). Each user can manage which shared or public folders to sync with her mobile devices by using the [Mobile Device Management](#mobile-device-management) WebApp plugin.

With the current Kopano implementation, delivering to the public store is configured separately from normal user management. There is the [move to public](https://documentation.kopano.io/kopanocore_administrator_manual/special_kc_configurations.html#move-to-public) plugin which moves incoming messages to a folder in the public store. It has a static configuration and does not support LDAP lookup. 

### Move to public with LDAP lookup

The `mlan/kopano` image include a extended version of the move to public plugin which use LDAP lookup, instead of a static file based lookup. When the plugin [move to public with LDAP](src/kopano/plugin/movetopublicldap.py) is enabled, `DAGENT_PLUGINS=movetopublicldap`, the kopano dagent will do two LDAP queries. The first is to search for an entry/user with matching email address. The second, introduced with this plugin, is to get the public folder from this entry. If found the message will be delivered to the public folder otherwise it will be delivered to the mailbox of the user.

Lets demonstrate how delivery to a public folder is configured. With this LDAP entry:

```yaml
dn: uid=public,ou=users,dc=example,dc=com
cn: public
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
sn: public
uid: public
mail: public@example.com
kopanoAccount: 1
kopanoHidden: 1
kopanoSharedStoreOnly: 1
kopanoResourceType: publicFolder:Public Stores/public
```

messages to `public@example.com` will be delivered to the public store in `Public Stores/public`.
The central [attribute](https://documentation.kopano.io/kopanocore_administrator_manual/appendix_b.html#appendix-b-ldap-attribute-description) is `kopanoResourceType: publicFolder:Public Stores/public`. It contains a token and a folder name. The token match is case sensitive and there must be a colon `:` separating
the token and the public folder name. The folder name can contain space and
sub folders, which are distinguished using a forward slash `/`.

The parameters in `/etc/kopano/ldap.cfg` will be used to arrange the LDAP queries.
The LDAP attribute holding the token and the token itself have the following
default values, which can be modified in `/etc/kopano/movetopublicldap.cfg` if desired.

```yaml
ldap_public_folder_attribute = kopanoResourceType
ldap_public_folder_attribute_token = publicFolder
```

As with other parameters, environment variables can be used to define them: `LDAP_PUBLIC_FOLDER_ATTRIBUTE=kopanoResourceType` and `LDAP_PUBLIC_FOLDER_ATTRIBUTE_TOKEN=publicFolder`.

## Shared folders

Users can share folders when sufficient permission have been granted. When logged into WebApp with an administrative account (`kopanoAdmin: 1`) you can modify the permissions on users shares and folders. Users can then, when logged into WebApp, open the inbox of other users by selecting `Open Shared Mails`.

The [impersonation](https://wiki.z-hub.io/display/ZP/Impersonation) mechanism allow such shared folders to be synced over [Exchange ActiveSync (EAS)](https://wiki.z-hub.io/display/ZP/Sharing+folders+and+Read-only) too. Each user can manage which shared or public folders to sync with her mobile devices by using the [Mobile Device Management](#mobile-device-management) WebApp plugin.

## Crontab

The `mlan/kopano` has a [cron](https://en.wikipedia.org/wiki/Cron) service activated. You can use environment variables to set up [crontab](https://man7.org/linux/man-pages/man5/crontab.5.html) entries. Any environment variable name staring with `CRONTAB_ENTRY` will be use to add entries to cron.

One trivial example is `CRONTAB_ENTRY_TEST=* * * * * root logger -t cron -p user.notice "SHELL=$$SHELL, PATH=$$PATH"`.

During the initial configuration procedure any `CRONTAB_ENTRY` will add crontab entries to the file `/etc/kopano/docker-crontab`, all the while previously present entries are deleted. This file defines the `PATH` variable so that you don't need to give full path names to commands in the crontab entry. This is, you need to provide the full path names to commands if this `PATH` definition is missing in the `/etc/kopano/docker-crontab` file.

## Mail transfer agent interaction

Environment variables can be used to configure where Kopano find the Mail Transfer Agent, such as Postfix. Likewise the Mail Transfer Agent need to know where to forward emails to.

#### `LMTP_LISTEN`

Added support (release 1.1.3) of the environment variable with default `LMTP_LISTEN=*:2003`, due to misconfiguration of `kopano-dagent` in recent releases (kopano-core 8.7.84).

#### `SMTP_SERVER`

Host name or IP address of the outgoing SMTP server. This server needs to relay mail for your server. Default: `SMTP_SERVER=localhost`

#### `SMTP_PORT`

TCP Port number used to contact the `SMTP_SERVER`. Default: `SMTP_PORT=25`

### Configuring postfix

The Kopano server listens to the port 2003 and expect the [LMTP](https://en.wikipedia.org/wiki/Local_Mail_Transfer_Protocol) protocol. For Postfix you can define `VIRTUAL_TRANSPORT=lmtp:mail-app:2003` assuming the `mlan/kopano` container is named `mail-app`

## Kopano-spamd integration with [mlan/postfix-amavis](https://github.com/mlan/docker-postfix-amavis)

[Kopano-spamd](https://kb.kopano.io/display/WIKI/Kopano-spamd) allow users to
drag messages into the Junk folder triggering the anti-spam filter to learn it as spam. If the user moves the message back to the inbox,
the anti-spam filter will unlearn it.

To allow kopano-spamd integration the kopano and postfix-amavis containers need to
share the `/var/lib/kopano/spamd` folder. If this directory exists within the
postfix-amavis container, the spamd-spam and spamd-ham service will be started.
They will run `sa-learn --spam` or `sa-learn --ham`,
respectively when a message is placed in either `var/lib/kopano/spamd/spam` or
`var/lib/kopano/spamd/ham`.

## Migrate old configuration to newer version of Kopano

Sometimes a new version of Kopano breaks compatibility with old configurations. The `mlan/kopano` include some functionality to address such situations. Use`MIGRATE_CONFIG` to try to attempt all or a list of available fixes. `MIGRATE_CONFIG=1 2 3` is an example of a list of fixes and `MIGRATE_CONFIG=all` attempts all fixes.

### `MIGRATE_CONFIG=1` Rejected insecure request as configuration for SECURE_COOKIES is true

Prior to Kopano WebApp version 5.0.0 the parameter was `define("INSECURE_COOKIES", true);` was used to allow HTTP access. Now [`define("SECURE_COOKIES", false);`](https://documentation.kopano.io/webapp_admin_manual/config.html#secure-cookies) is used instead. This fix tries to update the configuration accordingly.

### `MIGRATE_CONFIG=2` Make sure WebApp plugins have configuration files in place

The WebApp plugins S/MIME and MDM has recently been added to the `mlan/kopano` image. Old deployments might not have the related configuration files in place, preventing these plugins from running. This fix places default copies of configuration files in the configuration directory should they be missing.

# Knowledge base

Here some topics relevant for arranging a mail server are presented.

## Setup an LDAP directory server

A [Directory Server Agent (DSA)](https://en.wikipedia.org/wiki/Directory_System_Agent) is used to store, organize and present data in a key-value type format. Typically, directories are optimized for lookups, searches, and read operations over write operations, so they function extremely well for data that is referenced often but changes infrequently.

The [Lightweight Directory Access Protocol (LDAP)](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol), is an open protocol used to store and retrieve data from a hierarchical directory structure. Commonly used to store information about an organization and its assets and users.

[OpenLDAP](https://www.openldap.org/) is a cross platform LDAP based directory service. [Active Directory (AD)](https://en.wikipedia.org/wiki/Active_Directory) is a [directory service](https://en.wikipedia.org/wiki/Directory_service) developed by [Microsoft](https://en.wikipedia.org/wiki/Microsoft) for [Windows domain](https://en.wikipedia.org/wiki/Windows_domain) networks which also uses LDAP.

There are many dockerized OpenLDAP server to choose from. One such example is [mlan/openldap](https://github.com/mlan/docker-openldap).

### LDAP user entry

The data itself in an LDAP system is mainly stored in elements called attributes. Attributes are basically key-value pairs. Unlike in some other systems, the keys have predefined names which are dictated by the objectClasses selected for an entry. An entry is basically a collection of attributes under a name used to describe something; a user for example.

```yaml
dn: uid=demo,ou=users,dc=example,dc=com
objectclass: inetOrgPerson
uid: demo
```

### Kopano LDAP schema

The Kopano LDAP schema defines additional objectClasses and attributes. These allow the Kopano services, access for example, to controlled on per-user basis. More information on available attributes can be find here, [Fine-tuning user configuration](https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html?highlight=propmap#fine-tuning-user-configuration).

```shell
dn: uid=demo,ou=users,dc=example,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
objectClass: posixAccount
cn: demo
sn: demo
uid: demo
mail: demo@example.com
uidNumber: 1234
gidNumber: 1234
homeDirectory: /home/demo
telephoneNumber: 0123 123456789
title: MCP
kopanoEnabledFeatures: imap
kopanoEnabledFeatures: pop3
```

The schema needs to be added to the directory server. The Kopano installation files include the LDAP schema and can be found here `/usr/share/doc/kopano/kopano.ldif.gz`. For more details, see: [Kopano Knowledge Base/Install and optimize OpenLDAP for use with Kopano Groupware Core](https://kb.kopano.io/display/WIKI/Install+and+optimize+OpenLDAP+for+use+with+Kopano+Groupware+Core).

## Kopano WebApp HTTP access

The distribution installation of `kopano-webapp` only allow HTTPS access. The `mlan/kopano` image updates the configuration to [`define("SECURE_COOKIES", false);`](https://documentation.kopano.io/webapp_admin_manual/config.html#secure-cookies) in `/etc/kopano/webapp/config.php` also allowing HTTP access. This can be useful when arranging the `mlan/kopano` container behind a reverse proxy, like [Traefik](https://doc.traefik.io/traefik/), which then does the enforcement of HTTPS. Also see [`MIGRATE_CONFIG=1` Rejected insecure request as configuration for SECURE_COOKIES is true](#migrate_config1-rejected-insecure-request-as-configuration-for-secure_cookies-is-true).

## Mail client configuration

### Microsoft Outlook

Kopano, using [Z-Push](http://z-push.org/), allows native interfacing with Microsoft Outlook 2013 and above via the [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync) protocol, providing synchronization of mail, calendar, tasks and contacts. For details please see [Configuring Outlook](https://documentation.kopano.io/user_manual_kopanocore/configure_outlook.html).

It can be interesting to know that there is a [Kopano OL Extension](https://kb.kopano.io/display/WIKI/Setting+up+the+Kopano+OL+Extension) that can improve productivity. To install it [download](https://download.kopano.io/community/olextension%3A/) and run the `KopanoOLExtension-<version>-combined.exe` file on your Windows PC.

### Mobile devices

Most mobile devices, that is, Apple iOS, Android and Blackberry have support for [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync), providing synchronization of mail, calendar, tasks and contacts. For details please see [Configuring Mobile Devices](https://documentation.kopano.io/user_manual_kopanocore/configure_mobile_devices.html).

### Alternative mail synchronization

Some clients does not support [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync), e.g., Linux ones, in which case either the [IMAP](https://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) or [POP3](https://en.wikipedia.org/wiki/Post_Office_Protocol) protocol are used via the Kopano gateway. These protocols only handle incoming mail, so for sending mail clients need to interface directly with a [Mail Transfer Agent (MTA)](https://en.wikipedia.org/wiki/Message_transfer_agent) over [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol). For more details please see [Configuring Alternative Mail Clients](https://documentation.kopano.io/user_manual_kopanocore/configure_alternative_mail_clients.html).

Please note that IMAP and POP3 access are not enabled by default, see [Enabling IMAP and POP3 `DISABLED_FEATURES`](#enabling-imap-and-pop3-disabled_features).

### Alternative calendar synchronization

CalDAV offers calendar sync For more details please see [Configuring CalDAV Clients](https://documentation.kopano.io/user_manual_kopanocore/configure_caldav_clients.html).

### Mozilla Thunderbird

Thunderbird does not support [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync), so either [IMAP](https://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) or [POP3](https://en.wikipedia.org/wiki/Post_Office_Protocol) and SMTP is needed to synchronize mail, see [Alternative mail synchronization](#alternative-mail-synchronization).

To synchronize calendar, tasks and contacts CalDAV can be used. Interestingly Thunderbird has a add-on that provides calendar, tasks and contacts synchronization using [Exchange ActiveSync (EAS)](https://en.wikipedia.org/wiki/Exchange_ActiveSync), but not for mail. For details please see [Provider for Exchange ActiveSync](https://addons.thunderbird.net/en-US/thunderbird/addon/eas-4-tbsync/).

# Implementation

Here some implementation details are presented.

## Container init scheme

The container use [runit](http://smarden.org/runit/), providing an init scheme and service supervision, allowing multiple services to be started. There is a Gentoo Linux [runit wiki](https://wiki.gentoo.org/wiki/Runit).

When the container is started, execution is handed over to the script [`docker-entrypoint.sh`](src/docker/bin/docker-entrypoint.sh). It has 4 stages; 0) *register* the SIGTERM [signal (IPC)](https://en.wikipedia.org/wiki/Signal_(IPC)) handler, which is programmed to run all exit scripts in `/etc/docker/exit.d/` and terminate all services, 1) *run* all entry scripts in `/etc/docker/entry.d/`, 2) *start* services registered in `SVDIR=/etc/service/`, 3) *wait* forever, allowing the signal handler to catch the SIGTERM and run the exit scripts and terminate all services.

The entry scripts are responsible for tasks like, seeding configurations, register services and reading state files. These scripts are run before the services are started.

There is also exit script that take care of tasks like, writing state files. These scripts are run when docker sends the SIGTERM signal to the main process in the container. Both `docker stop` and `docker kill --signal=TERM` sends SIGTERM.

## Build assembly

The entry and exit scripts, discussed above, as well as other utility scrips are copied to the image during the build phase. The source file tree was designed to facilitate simple scanning, using wild-card matching, of source-module directories for files that should be copied to image. Directory names indicate its file types so they can be copied to the correct locations. The code snippet in the `Dockerfile` which achieves this is show below.

```dockerfile
COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/entry.d $DOCKER_ENTRY_DIR/
```

There is also a mechanism for excluding files from being copied to the image from some source-module directories. Source-module directories to be excluded are listed in the file [`.dockerignore`](https://docs.docker.com/engine/reference/builder/#dockerignore-file). Since we don't want files from the module `notused` we list it in the `.dockerignore` file:

```sh
src/notused
```

