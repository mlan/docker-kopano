#
# build arguments, amd64 is the default
#
ARG	DIST=ubuntu
ARG	REL=18.04
ARG	ARCH

FROM	${ARCH:+$ARCH/}$DIST:$REL AS base
LABEL	maintainer=mlan
ENV	DEBIAN_FRONTEND=noninteractive \
	DOCKER_BIN_DIR=/usr/local/bin \
	DOCKER_RUNSV_DIR=/etc/service \
	DOCKER_ENTRY_DIR=/etc/entrypoint.d \
	DOCKER_EXIT_DIR=/etc/exitpoint.d \
	DOCKER_CONF_DIR1=/etc/kopano \
	DOCKER_CONF_DIR2=/usr/share/z-push \
	DOCKER_USER=kopano \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1 \
	SYSLOG_OPTIONS='-S' \
	SYSLOG_LEVEL=4
#
# Copy utility scripts including entrypoint.sh to image
#
COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/entrypoint.d $DOCKER_ENTRY_DIR/
COPY	src/*/exitpoint.d $DOCKER_EXIT_DIR/

#
# Install helpers
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
	&& setup-runit.sh "syslogd -n -O - -l $SYSLOG_LEVEL $SYSLOG_OPTIONS"



FROM	base AS base-man
#
# get man pages to work
#
#
# Do not exclude man pages & other documentation
# Reinstall all currently installed packages in order to get the man pages back
#
ENV	DEBIAN_FRONTEND=noninteractive
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
	DOCKER_RUNSV_DIR=/etc/service \
	DOCKER_BIN_DIR=/usr/local/bin \
	LMTP_LISTEN=*:2003 \
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
	&& apt-get update \
	&& for i in $(seq ${DOCKER_BUILD_PASSES}); do echo "\033[1;36mKOPANO CORE INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $DOCKER_BUILD_DEB_DIR \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
	&& mkdir -p /var/lib/kopano/attachments && chown kopano: /var/lib/kopano/attachments \
	&& rm -rf $DOCKER_BUILD_DEB_DIR \
	&& setup-runit.sh \
	"kopano-dagent -l" \
	"kopano-gateway -F" \
	"kopano-ical -F" \
	"-f kopano-search -F" \
	"kopano-server -F" \
	"kopano-spooler -F" \
	"-d kopano-grapi serve" \
	"-d kopano-kapid serve --log-timestamp=false" \
	"-d kopano-konnectd serve --log-timestamp=false" \
	"-d kopano-monitor -F" \
	"-d kopano-presence -F" \
	"-d kopano-spamd -F"
#
# Have runit's runsvdir start all services
#
CMD	runsvdir -P ${DOCKER_RUNSV_DIR}
#
# Entrypoint, how container is run
#
ENTRYPOINT ["entrypoint.sh"]
#
# Check if all services are running
#
HEALTHCHECK CMD sv status ${DOCKER_RUNSV_DIR}/*



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
	DOCKER_RUNSV_DIR=/etc/service \
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
	&& apt-get update \
	&& for i in $(seq ${DOCKER_BUILD_PASSES}); do echo "\033[1;36mKOPANO WEBAPP INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $DOCKER_BUILD_DEB_DIR \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
	&& dpkg-reconfigure php7-mapi \
	&& conf replace /etc/kopano/webapp/config.php 'define("INSECURE_COOKIES", false);' 'define("INSECURE_COOKIES", true);' \
#	&& conf fixmissing /etc/php/7.?/apache2/conf.d/kopano.ini /etc/php/7.?/mods-available/kopano.ini /etc/php5/conf.d/kopano.ini \
	&& conf replace /etc/apache2/sites-available/kopano-webapp.conf 'Alias /webapp /usr/share/kopano-webapp' '<VirtualHost *:80>\\nDocumentRoot /usr/share/kopano-webapp' \
	&& echo '</VirtualHost>' >> /etc/apache2/sites-available/kopano-webapp.conf \
	&& conf modify /etc/apache2/apache2.conf '^ErrorLog' syslog:user \
	&& echo 'CustomLog "||/usr/bin/logger -t apache -i -p user.debug" common' >> /etc/apache2/apache2.conf \
	&& echo 'ServerName localhost' >> /etc/apache2/apache2.conf \
	&& mkdir -p /etc/kopano/theme/Custom \
	&& ln -sf /etc/kopano/theme/Custom /usr/share/kopano-webapp/plugins/. \
#	&& conf modify /etc/apache2/apache2.conf '^LogLevel' crit \
#	&& a2disconf other-vhosts-access-log \
	&& a2dissite 000-default.conf \
	&& a2ensite kopano-webapp \
	&& rm -rf $DOCKER_BUILD_DEB_DIR \
	&& setup-runit.sh "-f -s /etc/apache2/envvars -q apache2 -DFOREGROUND -DNO_DETACH -k start"
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
	DOCKER_RUNSV_DIR=/etc/service \
	DOCKER_BUILD_DEB_DIR=/tmp/deb \
	DOCKER_BUILD_PASSES=1
#
# Add Z-Push repository and install Z-Push configured to be used with kopano and apache
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
	&& conf addafter /etc/apache2/conf-available/z-push.conf 'Alias /Microsoft-Server-ActiveSync' 'AliasMatch (?i)/Autodiscover/Autodiscover.xml "/usr/share/z-push/autodiscover/autodiscover.php"' '</IfModule>' \
	&& conf replace /usr/share/z-push/config.php 'define(\x27LOGBACKEND\x27, \x27filelog\x27);' 'define(\x27LOGBACKEND\x27, \x27syslog\x27);'



FROM full AS debugtools
#
# Optionaly install debug tools
#
RUN	apt-get update && apt-get install --yes --no-install-recommends \
	less \
	nano \
	ldap-utils \
	htop \
	net-tools \
	lsof \
	iputils-ping
#
# clean up
#
#RUN	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



