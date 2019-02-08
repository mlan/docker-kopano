ARG	DIST=ubuntu
ARG	REL=18.04
ARG	ARCH=amd64



FROM	$ARCH/$DIST:$REL AS base
LABEL	maintainer=mlan
ENV	DEBIAN_FRONTEND=noninteractive \
	docker_build_runit_root=/etc/service \
	docker_build_deb_dir=/tmp/deb \
	docker_build_passes=1 \
	SYSLOG_LEVEL=4
#
# Copy helpers
#
COPY	assets/setup-runit.sh /usr/local/bin/
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
	&& setup-runit.sh "syslogd -n -O /dev/stdout -l $SYSLOG_LEVEL"



FROM	base AS base-man
#
# get man pages to work
#
#
# Do not exclude man pages & other documentation
# Reinstall all currently installed packages in order to get the man pages back
#
ENV	DEBIAN_FRONTEND=noninteractive
RUN	rm /etc/dpkg/dpkg.cfg.d/excludes \
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
FROM base-man AS kopano-core
#
# build arguments
#
ARG	DIST
ARG	REL
ARG	ARCH
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	docker_build_runit_root=/etc/service \
	docker_build_deb_dir=/tmp/deb \
	docker_build_passes=1
#
# Copy helpers
#
COPY	assets/kopano-webaddr.sh /usr/local/bin/
COPY	assets/dpkg-version.sh /usr/local/bin/
COPY	assets/conf /usr/local/bin/
COPY	assets/entrypoint.sh /usr/local/bin/
COPY	assets/healthcheck.sh /usr/local/bin/
#
# Install kopano-core
#
RUN	mkdir -p $docker_build_deb_dir \
	&& webaddr=$(kopano-webaddr.sh core \
	https://download.kopano.io/community ${DIST} ${REL} ${ARCH}) \
	&& echo "$webaddr<->${DIST} ${REL} ${ARCH}<-" \
	&& curl $webaddr | tar -xzC $docker_build_deb_dir \
	&& apt-get update \
	&& for i in $(seq ${docker_build_passes}); do echo "\033[1;36mKOPANO CORE INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $docker_build_deb_dir \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
#	&& rm -rf $docker_build_deb_dir \
	&& setup-runit.sh \
	"kopano-dagent -l" \
	"kopano-gateway -F" \
	"kopano-ical -F" \
	"kopano-search -F" \
	"kopano-server -F" \
	"kopano-spooler -F" \
	&& setup-runit.sh --down \
	"kopano-grapi serve" \
	"kopano-kapid serve --log-timestamp=false" \
	"kopano-konnectd serve --log-timestamp=false" \
	"kopano-monitor -F" \
	"kopano-presence -F" \
	"kopano-spamd -F"
#
# Entrypoint, how container is run
#
HEALTHCHECK --interval=5m --timeout=3s CMD healthcheck.sh
ENTRYPOINT ["entrypoint.sh"]



#
# Kopano-webapp
#
FROM kopano-core AS kopano-core-webapp
#
# build arguments
#
ARG	DIST
ARG	REL
ARG	ARCH
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	docker_build_runit_root=/etc/service \
	docker_build_deb_dir=/tmp/deb \
	docker_build_passes=1
#
# Install Kopano webapp
#
RUN	apt-get install --yes --no-install-recommends apache2 libapache2-mod-php7.2 \
	&& mkdir -p $docker_build_deb_dir \
	&& webaddr=$(kopano-webaddr.sh webapp \
	https://download.kopano.io/community ${DIST} ${REL} all) \
	&& echo "$webaddr<->${DIST} ${REL} all<-" \
	&& curl $webaddr | tar -xzC $docker_build_deb_dir \
	&& apt-get update \
	&& for i in $(seq ${docker_build_passes}); do echo "\033[1;36mKOPANO WEBAPP INSTALL PASS: $i\033[0m" \
	&& dpkg --install --force-depends --skip-same-version --recursive $docker_build_deb_dir \
	&& apt-get install --yes --no-install-recommends --fix-broken; done \
	&& dpkg-reconfigure php7-mapi \
	&& conf replace /etc/kopano/webapp/config.php 'define("INSECURE_COOKIES", false);' 'define("INSECURE_COOKIES", true);' \
#	&& conf fixmissing /etc/php/7.?/apache2/conf.d/kopano.ini /etc/php/7.?/mods-available/kopano.ini /etc/php5/conf.d/kopano.ini \
	&& conf replace /etc/apache2/sites-available/kopano-webapp.conf 'Alias /webapp /usr/share/kopano-webapp' '<VirtualHost *:80>\\nDocumentRoot /usr/share/kopano-webapp' \
	&& echo '</VirtualHost>' >> /etc/apache2/sites-available/kopano-webapp.conf \
	&& conf modify /etc/apache2/apache2.conf '^ErrorLog' syslog:user \
	&& echo 'CustomLog "||/usr/bin/logger -t apache -i -p user.notice" vhost_combined' >> /etc/apache2/apache2.conf \
	&& echo 'CustomLog "||/usr/bin/logger -t apache -i -p user.info" combined' >> /etc/apache2/apache2.conf \
	&& mkdir -p /etc/kopano/theme/Custom \
	&& ln -sf /etc/kopano/theme/Custom /usr/share/kopano-webapp/plugins/. \
#	&& conf modify /etc/apache2/apache2.conf '^LogLevel' crit \
#	&& a2disconf other-vhosts-access-log \
	&& a2dissite 000-default.conf \
	&& a2ensite kopano-webapp \
#	&& rm -rf $docker_build_deb_dir \
	&& setup-runit.sh "apache2ctl -D FOREGROUND -k start"
#
# Ports
#
EXPOSE	80 443



#
# Z-Push
#
FROM kopano-core-webapp AS kopano-full
#
# build arguments
#
ARG	DIST
ARG	REL
ARG	ARCH
#
# variables
#
ENV	DEBIAN_FRONTEND=noninteractive \
	docker_build_runit_root=/etc/service \
	docker_build_deb_dir=/tmp/deb \
	docker_build_passes=1
#
# Add Z-Push repository and install Z-Push configured to be used with kopano and apache
#
RUN	debaddr="$(kopano-webaddr.sh --deb final http://repo.z-hub.io/z-push: ${DIST} ${REL})" \
	&& echo "deb $debaddr/ /" > /etc/apt/sources.list.d/z-push.list \
	&& wget -qO - $debaddr/Release.key | apt-key add - \
	&& mkdir -p /var/lib/z-push && chown www-data:www-data /var/lib/z-push \
	&& mkdir -p /var/log/z-push && chown www-data:www-data /var/log/z-push \
	&& apt-get update && apt-get install --yes --no-install-recommends \
	z-push-backend-kopano \
	z-push-kopano \
	z-push-config-apache \
	z-push-autodiscover \
	z-push-state-sql \
	&& conf addafter /etc/apache2/conf-available/z-push.conf 'Alias /Microsoft-Server-ActiveSync' 'AliasMatch (?i)/Autodiscover/Autodiscover.xml "/usr/share/z-push/autodiscover/autodiscover.php"' '</IfModule>' \
	&& conf replace /usr/share/z-push/config.php 'define(\x27LOGBACKEND\x27, \x27filelog\x27);' 'define(\x27LOGBACKEND\x27, \x27syslog\x27);'



FROM kopano-full AS kopano-debugtools
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



