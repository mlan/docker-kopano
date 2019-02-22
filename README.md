# The `mlan/kopano` repository

![MicroBadger Size](https://img.shields.io/microbadger/image-size/mlan/kopano.svg?label=size&style=popout-square&logo=docker)
![docker stars](https://img.shields.io/docker/stars/mlan/kopano.svg?label=stars&style=popout-square&logo=docker)
![docker pulls](https://img.shields.io/docker/pulls/mlan/kopano.svg?label=pulls&style=popout-square&logo=docker)

This (non official) repository provides dockerized web mail service as well as ActiveSync, ICAL, IMAP and POP3 service. It is based on [Kopano](https://kopano.com) core components, as well as the Kopano WebApp and [Z-Push](http://z-push.org/). The image uses [nightly built packages](https://download.kopano.io/community/) which are provided by the Kopano community.

Hopefully this repository can be retired once the Kopano community make official images available. To learn more about this activity see [zokradonh/kopano-docker](https://github.com/zokradonh/kopano-docker).

## Features

Brief feature list follows below

- Groupware server [Kopano WebApp](https://kopano.io/)
- ActiveSync server [Z-Push](http://z-push.org/)
- Multi-staged build providing the images `full`, `debugtools` and `core`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script [conf](assets/conf) helping configuring Kopano components, WebApp and Z-Push
- Health check
- Hook for theming
- Demo based on `docker-compose.yml` and `Makefile` files

## Tags

The `mlan/kopano` repository contains a multi staged built. You select which build using the appropriate tag.

The version part of the tag is not based on the version of this repository. It is instead, based on the combined revision numbers of the nightly Kopano core and Kopano WebApp package suits that was available when building the images. For example, `8.7.80-3.5.2` indicates that the image was built using the 8.7.80 version of Kopano core and 3.5.2 version of Kopano WebApp.

The build part of the tag is one of `full`, `debugtools` and `core`. The image with tag `full` contain Kopano core components, as well as, the Kopano WebApp and Z-Push. The image with tag `debugtools` also contains some debug tools. The image with tag `core` contains the Kopano core components proving the server and IMAP, POP3 and ICAL access, but no web access.

The tags `latest`, `full`, `debugtools` or `core` all reference the most recent builds.

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

An example of how to configure an web mail server using [docker compose](https://docs.docker.com/compose) is given below. It defines 4 services, `mail-app`, `mail-mta`, `mail-db` and `auth`, which are the web mail server, the mail transfer agent, the SQL database and LDAP authentication respectively.

```yaml
version: '3.7'

services:
  mail-app:
    image: mlan/kopano
    networks:
      - backend
    ports:
      - "127.0.0.1:8080:80"
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
      - LDAP_USER_TYPE_ATTRIBUTE_VALUE=${LDAP_USEROBJ-posixAccount}
      - LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=${LDAP_GROUPOBJ-posixGroup}
      - MYSQL_DATABASE=${MYSQL_DATABASE-kopano}
      - MYSQL_USER=${MYSQL_USER-kopano}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD-secret}
      - SYSLOG_LEVEL=3
    volumes:
      - mail-conf:/etc/kopano
      - mail-atch:/var/lib/kopano/attachments
      - mail-sync:/var/lib/z-push

  mail-mta:
    image: mlan/postfix-amavis
    hostname: ${MAIL_SRV-mx}.${MAIL_DOMAIN-example.com}
    networks:
      - backend
    ports:
      - "127.0.0.1:25:25"
    depends_on:
      - auth
    environment:
      - MESSAGE_SIZE_LIMIT=${MESSAGE_SIZE_LIMIT-25600000}
      - LDAP_HOST=auth
      - VIRTUAL_TRANSPORT=lmtp:mail-app:2003
      - SMTP_RELAY_HOSTAUTH=${SMTP_RELAY_HOSTAUTH-}
      - SMTP_TLS_SECURITY_LEVEL=${SMTP_TLS_SECURITY_LEVEL-}
      - SMTP_TLS_WRAPPERMODE=${SMTP_TLS_WRAPPERMODE-no}
      - LDAP_USER_BASE=ou=${LDAP_USEROU-users},${LDAP_BASE-dc=example,dc=com}
      - LDAP_QUERY_FILTER_USER=(&(objectclass=${LDAP_USEROBJ-posixAccount})(mail=%s))
      - DKIM_SELECTOR=${DKIM_SELECTOR-default}
      - SYSLOG_LEVEL=4
    volumes:
      - mail-mta:/var

  mail-db:
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
      - mail-db:/var/lib/mysql

  auth:
    image: mlan/openldap
    networks:
      - backend
    environment:
      - LDAP_LOGLEVEL=parse
    volumes:
      - auth-db:/srv

networks:
  backend:

volumes:
  auth-db:
  mail-conf:
  mail-atch:
  mail-db:
  mail-mta:
  mail-sync:
```

This repository contains a [demo](demo) directory which hold the [docker-compose.yml](demo/docker-compose.yml) file as well as a [Makefile](demo/Makefile) which might come handy. From within the [demo](demo) directory you can start the `mlan/kopano` container simply by typing:

```bash
make init
```

Then you can assess WebApp on the URL [`http://localhost:8080`](http://localhost:8080) and log in with the user name `demo` and password `demo` . You can send a test email by typing:

```bash
make test
```

## Environment variables

When you create the `mlan/kopano` container, you can adjust the configuration of the Kopano server by passing one or more environment variables or on the docker run command line. Note that any pre-existing configuration files within the container will be left untouched.

To see all available configuration variables you can run `man` within the container by for example using the [Makefile](demo/Makefile) described above:

```bash
make mail-app-man_server
```

If you do, you will notice that configuration variable names are all lower case, but they will be matched with all uppercase environment variables by the container entrypoint script. 

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

## Persistent data

There are at least three directories which should be considered mounted; the configuration files, `/etc/kopano`, the mail attachments, if they are kept in files, `/var/lib/kopano/attachments` and the active sync device states, if they are kept in files, `/var/lib/z-push`.

## User authentication `USER_PLUGIN`

Kopano supports three different ways to manage user authentication. Use the `USER_PLUGIN` environment variable to select the source of the user base. Possible values are: `db` (default), `ldap` and `unix`.

 `db`: Retrieve the users from the Kopano database. Use the kopano-admin tool to create users and groups. There are no additional settings for this plug-in.

`ldap`: Retrieve the users and groups information from an LDAP server. All additional LDAP settings are needed see below

`unix`: Retrieve the users and groups information from the Linux password files. This option is probably not interesting here.

### LDAP authentication

An LDAP server with user accounts configured to be used with Kopano is needed, but how to set one up is out of our scope here, instead see: [Kopano Knowledge Base/Install and optimize OpenLDAP for use with Kopano Groupware Core](https://kb.kopano.io/display/WIKI/Install+and+optimize+OpenLDAP+for+use+with+Kopano+Groupware+Core).

Once the LDAP server is up and running, the `mlan/kopano` container can be configured to use it using environment variables. In addition to the variables discussed below also set `USER_PLUGIN=ldap`.

#### `LDAP_HOST`, `LDAP_PORT`, `LDAP_PROTOCOL`

These directives specify a single LDAP server to use. Defaults: `LDAP_HOST=localhost`, `LDAP_PORT=389`, `LDAP_PROTOCOL=ldap`

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

By default the `imap` and `pop3` services are disabled for all users. You can set the environment variable `DISABLED_FEATURES=` to enable both `imap` and `pop3`. In this list you can disable certain features for users. This list is space separated, and currently may contain the following features: `imap`, `pop3`. Default: `DISABLED_FEATURES=imap pop3`

### Logging `LOG_LEVEL`

The level of output for logging in the range from 0 to 6. 0 means no logging, 1 for critical messages only, 2 for error or worse, 3 for warning or worse, 4 for notice or worse, 5 for info or worse, 6 debug. Default: `LOG_LEVEL=3`

## Custom themes

You can easily customize the Kopano WebApp see [New! JSON themes in Kopano WebApp](https://kopano.com/blog/new-json-themes-in-kopano-webapp/). Once you have the files you can install them in your docker container using the receipt below, where we assume that the container name is `mail-app` and that the directory `mytheme` contains the `theme.json` and the other file defining the theme.

```bash
docker cp mytheme/. mail-app:/etc/kopano/theme/Custom
docker exec -it mail-app chown -R root: /etc/kopano/theme
docker exec -it mail-app conf replace /etc/kopano/webapp/config.php 'define("THEME", \x27\x27);' 'define("THEME", \x27Custom\x27);'
```

Please note that it is not possible to rename the directory `/etc/kopano/theme/Custom` within the container without further modifications.

### Mail transfer agent interaction

Environment variables can be used to configure where Kopano find the Mail Transfer Agent, such as Postfix. Likewise the Mail Transfer Agent need to know where to forward emails to.

#### `SMTP_SERVER`

Host name or IP address of the outgoing SMTP server. This server needs to relay mail for your server. Default: `SMTP_SERVER=localhost`

#### `SMTP_PORT`

TCP Port number used to contact the `SMTP_SERVER`. Default: `SMTP_PORT=25`

### Configuring postfix

The Kopano server listens to the port 2003 and expect the [LMTP](https://en.wikipedia.org/wiki/Local_Mail_Transfer_Protocol) protocol. For Postfix you can define `VIRTUAL_TRANSPORT=lmtp:mail-app:2003` assuming the `mlan/kopano` container is named `mail-app`
