#
# build arguments, amd64 is the default
#
ARG	DIST=ubuntu
ARG	REL=20.04
ARG	ARCH

FROM	${ARCH:+$ARCH/}$DIST:$REL AS base
LABEL	maintainer=mlan
ENV	DEBIAN_FRONTEND=noninteractive \
	PYTHONDONTWRITEBYTECODE=PleaseNoPyCache \
	SVDIR=/etc/service \
	DOCKER_BIN_DIR=/usr/local/bin \
	DOCKER_ENTRY_DIR=/etc/docker/entry.d \
	DOCKER_EXIT_DIR=/etc/docker/exit.d \
	DOCKER_CRONTAB_FILE=/etc/kopano/docker-crontab \
	DOCKER_CRONTAB_DIR=/etc/cron.d \
	DOCKER_CONF_DIR1=/etc/kopano \
	DOCKER_SMPL_DIR1=/usr/share/doc/kopano/example-config \
	DOCKER_PLUG_DIR=/usr/share/kopano-dagent/python/plugins \
	DOCKER_CONF_DIR2=/usr/share/z-push \
	DOCKER_APPL_LIB=/var/lib/kopano \
	DOCKER_APPL_SSL_DIR=/etc/kopano/ssl \
	DOCKER_ACME_SSL_DIR=/etc/ssl/acme \
	KOPANO_SPAMD_LIB=/var/lib/kopano/spamd \
	DOCKER_APPL_RUNAS=kopano \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1 \
	DOCKER_UNLOCK_FILE=/etc/kopano/.docker.unlock \
	SYSLOG_OPTIONS='-S' \
	SYSLOG_LEVEL=5
#
# Copy utility scripts including docker-entrypoint.sh to image
#
COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/entry.d $DOCKER_ENTRY_DIR/
COPY	src/*/exit.d $DOCKER_EXIT_DIR/
COPY	src/*/config $DOCKER_CONF_DIR1/
COPY	src/*/plugin $DOCKER_PLUG_DIR/

#
# Install helpers. Set bash as default shell. Setup syslogs service.
#
RUN	apt-get update && apt-get install --yes --no-install-recommends \
	apt-utils \
	busybox-syslogd \
	runit \
	wget \
	curl \
	ca-certificates \
	tar \
	gnupg \
	jq \
	inotify-tools \
	cron \
	&& ln -s $DOCKER_CRONTAB_FILE $DOCKER_CRONTAB_DIR \
	&& docker-service.sh \
	"syslogd -nO- -l$SYSLOG_LEVEL $SYSLOG_OPTIONS" \
	"cron -f"
#	"cron -f -L 4"



FROM	base AS base-man
#
# get man pages to work
#
#
# Do not exclude man pages & other documentation
# Reinstall all currently installed packages in order to get the man pages back
#
#ENV	DEBIAN_FRONTEND=noninteractive
RUN	rm -f /etc/dpkg/dpkg.cfg.d/excludes \
	&& apt-get update \
	&& dpkg -l | grep ^ii | cut -d' ' -f3 | xargs apt-get install -y --reinstall \
	&& apt-get install --yes --no-install-recommends \
	man \
	manpages \
	bash-completion \
	&& rm -r /var/lib/apt/lists/*



#
# Kopano-core
#
FROM base-man AS core
#
# build arguments, amd64 is the default
#
ARG	DIST
ARG	REL
ARG	ARCH=amd64
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	SVDIR=/etc/service \
	DOCKER_BIN_DIR=/usr/local/bin \
	LMTP_LISTEN=*:2003 \
	SA_GROUP=kopano \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1
#
# Install kopano-core
#
RUN	mkdir -p $DOCKER_BUILD_DEB_DIR \
	&& webaddr=$(kopano-webaddr.sh core \
	https://download.kopano.io/community ${DIST} ${REL} ${ARCH}) \
	&& echo "$webaddr<->${DIST} ${REL} ${ARCH}<-" \
	&& curl $webaddr | tar -xzC $DOCKER_BUILD_DEB_DIR \
	&& webaddr=$(kopano-webaddr.sh archiver \
	https://download.kopano.io/community ${DIST} ${REL} ${ARCH}) \
	&& echo "$webaddr<->${DIST} ${REL} ${ARCH}<-" \
	&& curl $webaddr | tar -xzC $DOCKER_BUILD_DEB_DIR \
	&& apt-get update \
	&& for i in $(seq ${DOCKER_BUILD_PASSES}); do echo "\033[1;36mKOPANO CORE INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $DOCKER_BUILD_DEB_DIR \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
	&& apt-get install --yes --no-install-recommends python3-ldap \
	&& mkdir -p /var/lib/kopano/attachments && chown $DOCKER_APPL_RUNAS: /var/lib/kopano/attachments \
	&& mkdir -p $DOCKER_APPL_SSL_DIR \
	&& mkdir -p $DOCKER_ACME_SSL_DIR \
	&& mkdir -p $KOPANO_SPAMD_LIB/ham && chown $DOCKER_APPL_RUNAS: $KOPANO_SPAMD_LIB/ham \
	&& rm -rf $DOCKER_BUILD_DEB_DIR \
	&& rm $DOCKER_CONF_DIR1/*.cfg \
	&& . docker-common.sh \
	&& . docker-config.sh \
	&& dc_comment /etc/ssl/openssl.cnf RANDFILE \
	&& docker-service.sh \
	"kopano-dagent -l" \
	"kopano-gateway" \
	"kopano-ical" \
	"kopano-search" \
	"kopano-server" \
	"kopano-spooler" \
	"-f kopano-spamd" \
	"-d kopano-grapi serve" \
	"-d kopano-kapid serve --log-timestamp=false" \
	"-d kopano-konnectd serve --log-timestamp=false" \
	"-d kopano-monitor" \
	&& echo "This file unlocks the configuration, so it will be deleted after initialization." > $DOCKER_UNLOCK_FILE
#
# Have runit's runsvdir start all services
#
CMD	runsvdir -P ${SVDIR}
#
# Entrypoint, how container is run
#
ENTRYPOINT ["docker-entrypoint.sh"]
#
# Check if all services are running
#
HEALTHCHECK CMD sv status ${SVDIR}/*



#
# Kopano-webapp
#
FROM core AS core-webapp
#
# build arguments
#
ARG	DIST
ARG	REL
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	SVDIR=/etc/service \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1
#
# Install Kopano webapp
#
RUN	apt-get install --yes --no-install-recommends apache2 libapache2-mod-php \
	&& mkdir -p $DOCKER_BUILD_DEB_DIR \
	&& webaddr=$(kopano-webaddr.sh webapp \
	https://download.kopano.io/community ${DIST} ${REL} all) \
	&& echo "$webaddr<->${DIST} ${REL} all<-" \
	&& curl $webaddr | tar -xzC $DOCKER_BUILD_DEB_DIR \
	&& webaddr=$(kopano-webaddr.sh mdm \
	https://download.kopano.io/community ${DIST} ${REL} all) \
	&& echo "$webaddr<->${DIST} ${REL} all<-" \
	&& curl $webaddr | tar -xzC $DOCKER_BUILD_DEB_DIR \
	&& webaddr=$(kopano-webaddr.sh smime \
	https://download.kopano.io/community ${DIST} ${REL} ${ARCH}) \
	&& echo "$webaddr<->${DIST} ${REL} all<-" \
	&& curl $webaddr | tar -xzC $DOCKER_BUILD_DEB_DIR \
	&& apt-get update \
	&& for i in $(seq ${DOCKER_BUILD_PASSES}); do echo "\033[1;36mKOPANO WEBAPP INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $DOCKER_BUILD_DEB_DIR \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
	&& dpkg-reconfigure php7-mapi \
	&& . docker-common.sh \
	&& . docker-config.sh \
	&& dc_replace /etc/kopano/webapp/config.php 'define("SECURE_COOKIES", true);' 'define("SECURE_COOKIES", false);' \
	&& dc_replace /etc/apache2/sites-available/kopano-webapp.conf 'Alias /webapp /usr/share/kopano-webapp' '<VirtualHost *:80>\\nDocumentRoot /usr/share/kopano-webapp' \
	&& echo '</VirtualHost>' >> /etc/apache2/sites-available/kopano-webapp.conf \
	&& dc_modify /etc/apache2/apache2.conf '^ErrorLog' syslog:user \
	&& echo 'CustomLog "||/usr/bin/logger -t apache -i -p user.debug" common' >> /etc/apache2/apache2.conf \
	&& echo 'ServerName localhost' >> /etc/apache2/apache2.conf \
	&& mkdir -p /etc/kopano/theme/Custom \
	&& ln -sf /etc/kopano/theme/Custom /usr/share/kopano-webapp/plugins/. \
#	&& dc_modify /etc/apache2/apache2.conf '^LogLevel' crit \
	&& a2disconf other-vhosts-access-log \
	&& a2dissite 000-default.conf \
	&& a2ensite kopano-webapp \
	&& rm -rf $DOCKER_BUILD_DEB_DIR \
	&& cp -r $DOCKER_CONF_DIR1/webapp $DOCKER_SMPL_DIR1 \
	&& docker-service.sh "-f -s /etc/apache2/envvars -q apache2 -DFOREGROUND -DNO_DETACH -k start"
#
# Ports
#
EXPOSE	80 443



#
# Z-Push
#
FROM core-webapp AS full
#
# build arguments
#
ARG	DIST
ARG	REL
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	SVDIR=/etc/service \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1
#
# Add Z-Push repository and install Z-Push configured to be used with Kopano and Apache
#
RUN	debaddr="$(kopano-webaddr.sh --deb final http://repo.z-hub.io/z-push: ${DIST} ${REL})" \
	&& echo "deb $debaddr/ /" > /etc/apt/sources.list.d/z-push.list \
	&& wget -qO - $debaddr/Release.key | apt-key add - \
	&& mkdir -p /var/lib/z-push && chown www-data: /var/lib/z-push \
	&& mkdir -p /var/log/z-push && chown www-data: /var/log/z-push \
	&& apt-get update && apt-get install --yes --no-install-recommends \
	z-push-backend-kopano \
	z-push-kopano \
	z-push-config-apache \
	z-push-autodiscover \
	z-push-state-sql \
	&& . docker-common.sh \
	&& . docker-config.sh \
	&& dc_addafter /etc/apache2/conf-available/z-push.conf 'Alias /Microsoft-Server-ActiveSync' 'AliasMatch (?i)/Autodiscover/Autodiscover.xml "/usr/share/z-push/autodiscover/autodiscover.php"' '</IfModule>' \
	&& dc_replace /usr/share/z-push/config.php 'define(\x27USE_CUSTOM_REMOTE_IP_HEADER\x27, false);' 'define(\x27USE_CUSTOM_REMOTE_IP_HEADER\x27, \x27HTTP_X_FORWARDED_FOR\x27);' \
	&& dc_replace /usr/share/z-push/config.php 'define(\x27LOGBACKEND\x27, \x27filelog\x27);' 'define(\x27LOGBACKEND\x27, \x27syslog\x27);'

