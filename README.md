# The mlan/kopano repository

This (unofficial) repository provides dockerized web mail service as well as ActiveSync, ICAL, IMAP and POP3 service. It is based on [Kopano]() core components, as well as the Kopano WebApp and [Z-Push](http://z-push.org/). The image uses [nightly built packages](https://download.kopano.io/community/) which are provided by the Kopano community. 

Hopefully this repository can be retired once the Kopano community make official images available. There is some evidence of such activity on [dockerhub:kopano](https://hub.docker.com/u/kopano).

## Feature overview

Brief feature list follows below

- Groupware server [Kopano WebApp](https://kopano.io/) 
- ActiveSync server [Z-Push](http://z-push.org/)
- Multi-staged build providing the images `-full `, `-debugtools` , `-core` and  `-webapp`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script `conf` helping configuring Kopano components, WebApp and Z-Push
- Health check
- Hook for theming 

## Tags overview

The mlan/kopano repository contains a multi staged built. You select which build using the appropriate tag. 

The version part of the tag is `latest`  or the combined revision numbers of the nightly kopano-core and kopano-webapp package suits that  was available when building this image. For example, `8.7.80-3.5.2` indicates that the image was built using the 8.7.80 version of Kopano core and 3.5.2 version of Kopano webapp.

The build part of the tag is one of  `full `, `debugtools` , `core` and soon also `webapp`. The image with tag  `full` or without ending contain Kopano core components, as well as, the Kopano webapp and z-push. The image with tag  `debugtools` also contains some debug tools. The image with tag  `core` contains the kopano-core components proving the server and imap, pop3 and ical access. The image with tag  `webapp` contains the Kopano webapp and z-push proving web and active sync service which will depend on a kopano server running in a separate container or elsewhere. 

To exemplify the usage of the tags, lets assume that the latest version tag is `8.7.80-3.5.2`. In this case `latest`,  `8.7.80-3.5.2`, `full`, `latest-full` and  `8.7.80-3.5.2-full` all identify the same image.  

# Usage

In most use cases the `mlan/kopano` container also needs a SQL database (e.g., [MySQL](https://hub.docker.com/_/mysql) or [MariaDB](https://hub.docker.com/_/mariadb)), Mail Transfer Agent (e.g., [Postfix](http://www.postfix.org/)) and authentication (e.g., [OpenLDAP](https://www.openldap.org/)).  Docker images of such services are available. The docker compose example below is used to demonstrate how to configure these services. 

```bash
docker run -d --name mail-app -p 80:80 mlan/kopano
```

## Docker compose example

An example of how to configure an web mail server using docker compose is given below. It defines five services, `mail-app`, `mail-mta`, `mail-db`, `auth` and `proxy`, which are the web mail server, the mail transfer agent, the SQL database, authentication and reverse proxy respectively. 

```yaml
version: '3.7'

services:
  mail-app:
    image: mlan/kopano
    restart: unless-stopped
    networks:
      - proxy
      - backend
    ports:
      - "80:80"
    labels:
      - traefik.enable=true
      - traefik.frontend.rule=Host:mail.${DOMAIN-docker.localhost}
      - traefik.docker.network=${COMPOSE_PROJECT_NAME}_proxy
      - traefik.port=80
    depends_on:
      - auth
      - mail-db
      - mail-mta
    environment:
      - USER_PLUGIN=ldap
      - LDAP_HOST=auth
      - MYSQL_HOST=mail-db
      - SMTP_SERVER=mail-mta
      - LDAP_SEARCH_BASE=${LDAP_BASE-dc=example,dc=com}
      - LDAP_USER_TYPE_ATTRIBUTE_VALUE=kopano-user
      - LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=kopano-group
      - LDAP_USER_SEARCH_FILTER=(kopanoAccount=1)
      - SYSLOG_LEVEL=4
    env_file:
      - .init.env
    volumes:
      - mail-conf:/etc/kopano
      - mail-atch:/var/lib/kopano/attachments
      - mail-sync:/var/lib/z-push

  mail-mta:
    image: mlan/postfix-amavis
    restart: unless-stopped
    hostname: ${MAIL_SRV-mx}.${MAIL_DOMAIN-docker.localhost}
    networks:
      - backend
    ports:
      - "25:25"
    labels:
      - traefik.enable=true
      - traefik.frontend.rule=Host:${MAIL_SRV-mx}.${MAIL_DOMAIN-docker.localhost}
      - traefik.docker.network=${COMPOSE_PROJECT_NAME}_proxy
      - traefik.port=80
    depends_on:
      - auth
    environment:
      - MESSAGE_SIZE_LIMIT=${MESSAGE_SIZE_LIMIT-25600000}
      - LDAP_HOST=auth
      - VIRTUAL_TRANSPORT=lmtp:mail-app:2003
      - SMTP_RELAY_HOSTAUTH=${SMTP_RELAY_HOSTAUTH-}
      - SMTP_TLS_SECURITY_LEVEL=${SMTP_TLS_SECURITY_LEVEL-}
      - SMTP_TLS_WRAPPERMODE=${SMTP_TLS_WRAPPERMODE-no}
      - LDAP_USER_BASE=${LDAP_USEROU},${LDAP_BASE}
      - LDAP_GROUP_BASE=${LDAP_GROUPOU},${LDAP_BASE}
      - LDAP_QUERY_FILTER_USER=(&(kopanoAccount=1)(mail=%s))
      - LDAP_QUERY_FILTER_ALIAS=(&(kopanoAccount=1)(kopanoAliases=%s))
      - LDAP_QUERY_FILTER_GROUP=(&(objectclass=kopano-group)(mail=%s))
      - LDAP_QUERY_FILTER_EXPAND=(&(objectclass=kopano-user)(uid=%s))
      - DKIM_SELECTOR=${DKIM_SELECTOR-default}
      - SYSLOG_LEVEL=5
    env_file:
      - .init.env
    volumes:
      - mail-mta:/var
      - proxy-acme:/acme

  mail-db:
    image: mariadb
    restart: unless-stopped
    command: ['--log_warnings=1']
    networks:
      - backend
    environment:
      - LANG=C.UTF-8
    env_file:
      - .init.env
    volumes:
      - mail-db:/var/lib/mysql

  auth:
    image: mlan/openldap:1
    restart: unless-stopped
    networks:
      - backend
    environment:
      - LDAP_LOGLEVEL=parse
    volumes:
      - auth-conf:/srv/conf
      - auth-data:/srv/data

  proxy:
    image: traefik:alpine
    restart: unless-stopped
    command:
      - "--api"
      - "--docker"
      - "--defaultentrypoints=http,https"
      - "--entrypoints=Name:http Address::80 Redirect.EntryPoint:https"
      - "--entrypoints=Name:https Address::443 TLS"
      - "--retry"
      - "--docker.domain=${DOMAIN-docker.localhost}"
      - "--docker.exposedbydefault=false"
      - "--docker.watch=true"
      - "--acme"
      - "--acme.email=${CERTMASTER-certmaster}@${DOMAIN-docker.localhost}"
      - "--acme.entrypoint=https"
      - "--acme.onhostrule=true"
      - "--acme.storage=/acme/acme.json"
      - "--acme.httpchallenge"
      - "--acme.httpchallenge.entrypoint=http"
      - "--loglevel=ERROR"
    cap_drop:
      - all
    cap_add:
      - net_bind_service
    networks:
      - proxy
    ports:
      - "80:80"       # The HTTP port
      - "443:443"     # The HTTPS port
    labels:
      - traefik.enable=true
      - traefik.docker.network=${COMPOSE_PROJECT_NAME}_proxy
      - traefik.port=8080
      - traefik.frontend.passHostHeader=true
      - traefik.frontend.rule=Host:monitor.${DOMAIN-docker.localhost}
      - traefik.frontend.auth.basic=${PROXY_USER-admin}:${PROXY_PASSWORD-secret}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - proxy-acme:/acme
      - /dev/null:/traefik.toml

networks:
  proxy:
  backend:

volumes:
  mail-conf:
  mail-atch:
  mail-db:
  mail-mta:
  mail-sync:
  proxy-acme:

```

## Environment variables

When you create the `mlan/kopano` container, you can adjust the configuration of the Kopano server by passing one or more environment variables or on the docker run command line. Note that any pre-existing configuration files within the container will be left untouched.

To see all available configuration variables you can run `man` within the container, for example like this:

```bash
docker exec mail-app man kopano-server.cfg
```

If you do, you will notice that configuration variable names are all lower case, but they will be matched with all uppercase environment variables by the container entrypoint script. 

## SQL database configuration

The Kopano server uses a SQL database, which needs to be initiated, see below. Once the SQL database has been initiated you can create the Kopano container and configure it to use the SQL database using  environment variables.

#### `MYSQL_HOST`

The hostname of the MySQL server to use. Default `MYSQL_HOST=localhost`.

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

When the attachment_storage option is  `ATTACHMENT_STORAGE=files`, this option controls the compression level for the attachments. Higher compression levels will compress data better, but at the cost of CPU usage. Lower compression levels will require less CPU but will compress data less. Setting the compression level to 0 will effectively disable compression completely. Changing the compression level, or switching it on or off, will not affect any existing attachments, and will remain accessible as normal. Set to 0 to disable compression completely. The maximum compression level is 9. Default: `ATTACHMENT_COMPRESSION=6`

### SQL Database initialization

When creating the SQL container you can use environment variables to initiate it. For example, `MYSQL_ROOT_PASSWORD=topsecret`, `MYSQL_DATABASE=kopano`, `MYSQL_USER=kopano` and `MYSQL_PASSWORD=verysecret`.

## Persistent data

There are at least three directories which should be considered mounted; the configuration files, `/etc/kopano`, the mail attachments, if they are kept in files, `/var/lib/kopano/attachments` and the active sync device states, if they are kept in files, `/var/lib/z-push`.

## User authentication `USER_PLUGIN`

Kopano supports three different ways to manage user authentication. Use the `USER_PLUGIN` environment variable to select the source of the user base. Possible values are: `db` (default), `ldap` and `unix`.

 `db`: Retrieve the users from the Kopano database. Use the kopano-admin tool to create users and groups. There are no additional settings for this plugin.

`ldap`: Retrieve the users and groups information from an LDAP server. All additional LDAP settings are needed see below

`unix`: Retrieve the users and groups information from the Linux password files. This option is probably not interesting here.

### LDAP authentication

An LDAP server with user accounts configured to be used with Kopano is needed, but how to set one up is out of our scope here, instead see: [Kopano Knowledge Base/Install and optimize OpenLDAP for use with Kopano Groupware Core](https://kb.kopano.io/display/WIKI/Install+and+optimize+OpenLDAP+for+use+with+Kopano+Groupware+Core).

Once the LDAP server is up and running, the `mlan/kopano` container can be configured to use it using environment variables. In addition  to the variables discussed below also set `USER_PLUGIN=ldap`.

#### `LDAP_HOST`, `LDAP_PORT`, `LDAP_PROTOCOL`

These directives specify a single LDAP server to use. Defaults:  `LDAP_HOST=localhost`, `LDAP_PORT=389`, `LDAP_PROTOCOL=ldap` 

#### `LDAP_SEARCH_BASE`

This is the subtree entry where all objects are defined in the LDAP server. Default: `LDAP_SEARCH_BASE=dc=kopano,dc=com`

#### `LDAP_USER_TYPE_ATTRIBUTE_VALUE`

This variable determines what defines a valid Kopano user. Default: `LDAP_USER_TYPE_ATTRIBUTE_VALUE=posixAccount`

#### `LDAP_GROUP_TYPE_ATTRIBUTE_VALUE`

This variable determines what defines a valid Kopano group. Default: `LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=posixGroup`

#### `LDAP_USER_SEARCH_FILTER`

Adds an extra filter to the user search. Default `LDAP_USER_SEARCH_FILTER=`

Hint: Use the `kopanoAccount` attribute in the filter to differentiate between non-kopano and kopano users.

### Enabling IMAP and POP3 `DISABLED_FEATURES`

By default the `imap` and `pop3` services are disabled for all users. You can set the environment variable `DISABLED_FEATURES=` to enable both `imap` and `pop3`. In this list you can disable certain features for users.   This list is space separated, and currently may contain the following features: `imap`, `pop3`. Default:  `DISABLED_FEATURES=imap pop3`

### Logging `LOG_LEVEL`

The level of output for logging in the range from 0 to 6. 0 means no logging, 1 for critical messages only, 2 for error or worse, 3 for warning or worse, 4 for notice or worse, 5 for info or worse, 6 debug. Default: `LOG_LEVEL=3`

## Custom themes

You can easily customize the Kopano WebApp see [New! JSON themes in Kopano WebApp](https://kopano.com/blog/new-json-themes-in-kopano-webapp/). Once you have the files you can install them in your docker container using the receipt below, where we assume that the container name is `mail-app` and that the directory `mytheme` contains the `theme.json` and the other file defining the theme.

```bash
$ docker cp mytheme/. mail-app:/etc/kopano/theme/Custom
$ docker exec mail-app chown -R root:root /etc/kopano/theme
$ docker exec mail-app conf replace /etc/kopano/webapp/config.php 'define("THEME", \x27\x27);' 'define("THEME", \x27Custom\x27);'
```

Please note that it is not possible to rename the directory `/etc/kopano/theme/Custom` within the container without further modifications.

### Mail transfer agent interaction

Environment variables can be used to configure where Kopano find the Mail Transfer Agent, such as Postfix. Likewise the Mail Transfer Agent need to know where to forward emails to.

#### `SMTP_SERVER`

Hostname or IP address of the outgoing SMTP server. This server needs to relay mail for your server. Default: `SMTP_SERVER=localhost`

#### `SMTP_PORT`

TCP Port number for smtp_server.  Default: `SMTP_PORT=25`

### Configuring postfix

The Kopano server listens to the port 2003 and expect the LMTP protocol. For Postfix you can define `VIRTUAL_TRANSPORT=lmtp:mail-app:2003` assuming the `mlan/kopano` container is named `mail-app`