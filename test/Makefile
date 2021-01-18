# Makefile
#
# test
#

-include    *.mk

TST_REPO ?= mlan/kopano
TST_VER  ?= latest
_ver      = $(if $(findstring latest,$(1)),$(2),$(2)-$(1))

NET_NAME ?= test-net
NET_ENV  ?= --network $(NET_NAME)

AD_BASE  ?= dc=example,dc=com
AD_DOM   ?= $(call ad_sub_dot, $(AD_BASE))
AD_DC    ?= $(call ad_cut_dot, 1, 1, $(AD_DOM))
AD_GRP_OU ?= groups
AD_USR_OB ?= kopano-user
AD_USR_OU ?= users
AD_USR_CN ?= hero
AD_USR_PW ?= enigma

MAIL_SUB ?= ~~~test~message~~~
MAIL_MSG ?= Enjoy!

WEB_TIT  ?= "Kopano WebApp"

SQL_BASE ?= kopano
SQL_USER ?= kopano
SQL_PASS ?= secret
SQL_ENV  ?= \
-e MYSQL_DATABASE=$(SQL_BASE) \
-e MYSQL_USER=$(SQL_USER) \
-e MYSQL_PASSWORD=$(SQL_PASS) \

APP_NAME ?= app
APP_FQDN ?= $(APP_NAME).$(AD_DOM)
APP_CERT ?= ssl/$(APP_FQDN).crt
APP_KEY  ?= ssl/$(APP_FQDN).key
APP_VOL  ?=
APP_SLOG ?= 7
APP_ALOG ?= 6
APP_ENV  ?= $(NET_ENV) $(SQL_ENV) \
--name $(APP_NAME) \
--hostname $(APP_FQDN) \
-e MYSQL_HOST=$(DB_NAME) \
-e USER_PLUGIN=ldap \
-e LDAP_URI=ldap://$(AUT_NAME):389/ \
-e LDAP_SEARCH_BASE=$(AD_BASE) \
-e LDAP_USER_TYPE_ATTRIBUTE_VALUE=$(AD_USR_OB) \
-e LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=$(AD_GRP_OU) \
-e LDAP_PROPMAP= \
-e IMAP_LISTEN=*:143 \
-e POP3_LISTEN=*:110 \
-e ICAL_LISTEN=*:8080 \
-e DISABLED_FEATURES= \
-e LOGLEVEL=LOGLEVEL_DEBUG \
-e SYSLOG_LEVEL=$(APP_SLOG) \
-e LOG_LEVEL=$(APP_ALOG)
APPS_ENV ?= $(APP_ENV) \
-e IMAPS_LISTEN=*:993 \
-e POP3S_LISTEN=*:995 \
-e ICALS_LISTEN=*:8443
APPA_ENV ?= $(APPS_ENV) \
-v $(shell pwd)/acme:/acme

AUT_NAME ?= auth
AUT_IMG  ?= mlan/openldap
AUT_FQDN ?= $(AUT_NAME).$(AD_DOM)
AUT_VOL  ?=
AUT_ENV  ?= $(NET_ENV) \
--name $(AUT_NAME) \
--hostname $(AUT_FQDN)

TAW_NAME ?= throwaway
TAW_ENV  ?= --entrypoint /bin/bash \
--name $(TAW_NAME) \
--rm

CURL_OPT ?= -s -v
CURL_IMG ?= curlimages/curl
CURL_ENV ?= $(NET_ENV) \
-i --rm

DB_NAME  ?= db
DB_IMG   ?= mariadb
DB_FQDN  ?= $(DB_NAME).$(AD_DOM)
DB_VOL   ?=
DB_CMD   ?= --log_warnings=1
DB_ENV   ?= $(NET_ENV) $(SQL_ENV) \
--name $(DB_NAME) \
--hostname $(DB_FQDN) \
-e MYSQL_ROOT_PASSWORD=$(SQL_PASS)

GREP_ENV ?=

TST_W8S1 ?= 1
TST_W8S2 ?= 20
TST_W8L1 ?= 20
TST_W8L2 ?= 120

export define LDIF_ADD_DATA
dn: $(AD_BASE)
objectClass: organization
objectClass: dcObject
dc: $(AD_DC)
o: $(AD_DOM)

dn: ou=$(AD_USR_OU),$(AD_BASE)
objectClass: organizationalUnit
ou: $(AD_USR_OU)

dn: ou=$(AD_GRP_OU),$(AD_BASE)
objectClass: organizationalUnit
ou: $(AD_GRP_OU)

dn: uid=$(AD_USR_CN),ou=$(AD_USR_OU),$(AD_BASE)
objectClass: inetOrgPerson
objectClass: $(AD_USR_OB)
cn: $(AD_USR_CN)
sn: $(AD_USR_CN)
uid: $(AD_USR_CN)
mail: $(AD_USR_CN)@$(AD_DOM)
kopanoAccount: 1
userPassword: $(AD_USR_PW)
endef


variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

test-all: test-up_0 test_1 test_2 test_3
	

test_%: test-up_% test-waitl_% test-logs_% test-service_% test-down_%
	

test-pull:
	$(addprefix docker pull ,$(CURL_IMG); $(AUT_IMG); $(DB_IMG))

test-up_0: test-up-net
	#
	#
	#
	# test (0) run without envvars (is there smoke?)
	#
	# run containers see if there are logs and stop.
	#
	#
	docker run -d --name $(APP_NAME) $(TST_REPO):$(call _ver,$(TST_VER),core)
	sleep $(TST_W8L1)
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'
	docker rm -fv $(APP_NAME)
	sleep $(TST_W8S1)
	docker run -d --name $(APP_NAME) $(TST_REPO):$(call _ver,$(TST_VER),full)
	sleep $(TST_W8L1)
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'
	docker rm -fv $(APP_NAME)
	sleep $(TST_W8S1)
	#
	#
	# test (0) success ☺
	#
	#
	#

test-up_1: test-up-net test-up-deps_1 test-up-auth_1
	#
	#
	#
	# test (1) ldap auth, sql db, and mail send recv
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3://app
	# recv: curl imap://app
	#
	#
	docker run -d $(APP_ENV) $(APP_VOL) $(TST_REPO):$(call _ver,$(TST_VER),core)

test-up_2: test-up-net test-up-deps_2 test-up-auth_2
	#
	#
	#
	# test (2) ldap auth, sql db, mail send recv secure using pem cert files
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3s://app
	# recv: curl imaps://app
	#
	#
	docker run -d $(APPS_ENV) $(APP_VOL) $(TST_REPO):$(call _ver,$(TST_VER),core)

test-up_3: test-up-net test-up-deps_3 test-up-auth_3 acme/acme.json
	#
	#
	#
	# test (3) ldap auth, sql db, mail send recv secure using acme cert
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3s://app
	# recv: curl imaps://app
	# web: curl http://app
	#
	#
	docker run -d $(APPA_ENV) $(APP_VOL) $(TST_REPO):$(call _ver,$(TST_VER),full)

test-up: test-up_1

test-service: test-service_0

test-service_%: test-pop3_% test-imap_% test-http_%
	#
	#
	# test ($*) success ☺
	#
	#
	#

test-logs_%:
	-docker ps -a
	-docker container logs $(AUT_NAME)
	-docker container logs $(DB_NAME)
	-docker container logs $(APP_NAME) # | grep 'docker-entrypoint.sh'

test-waits_%:
	case $* in [1-4]) sleep $(TST_W8S1);; *) sleep $(TST_W8S2);; esac

test-waitl_%:
	case $* in [1-4]) sleep $(TST_W8L1);; *) sleep $(TST_W8L2);; esac

test-up-net:
	docker network create $(NET_NAME) 2>/dev/null || true

test-down-net:
	docker network rm $(NET_NAME) || true

test-down: test-down_0
	docker network rm $(NET_NAME) 2>/dev/null || true

test-down_%:
	@docker rm -fv $(APP_NAME) $(DB_NAME) $(AUT_NAME) $(TAW_NAME)  2>/dev/null || true
	@if [ $* -ge 0 ]; then sleep $(TST_W8S1); fi

test-up-deps_%:
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG) $(DB_CMD)
	docker run -d $(AUT_ENV) $(AUT_VOL) $(AUT_IMG)

test-up-auth_%:
	sleep $(TST_W8L1)
	docker run $(TAW_ENV) $(TST_REPO):$(call _ver,$(TST_VER),core) \
	zcat /usr/share/doc/kopano/kopano.ldif.gz \
	| docker exec -i $(AUT_NAME) ldapadd -Q
	echo "$$LDIF_ADD_DATA" | docker exec -i $(AUT_NAME) ldapadd -Q

test-lmtp: test-lmtp_0
test-lmtp_%:
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(AD_USR_CN)@$(AD_DOM)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(AD_USR_CN)@$(AD_DOM)>\nDate: $$(date)\nSubject: $(MAIL_SUB)$*\n$(MAIL_MSG)$*\n.\nQUIT\n"\
	| nc -C $(call dkr_cnt_ip,$(APP_NAME)) 2003 # > /dev/null
#	| nc -C localhost 2003 # > /dev/null
	case $* in [1-3]) sleep $(TST_W8S1);; [4-9]) sleep $(TST_W8S2);; esac

test-cfg_%:
	$(eval cfg_s := $(shell [ $* -ge 2 ] && echo s))

# Note: cannot use prereq also in a proper target since it will change the
# prereq order, eg. avoid the "3" in test-imaps: test-imap_3
test-imap: test-imap_0
test-imaps: test-imap_9
test-imap_%: test-cfg_% test-lmtp_%
	docker run $(CURL_ENV) $(CURL_IMG) $(CURL_OPT) imap$(cfg_s)://$(APP_NAME)/inbox \
	--ssl --anyauth -k -X "fetch 1 all" -u $(AD_USR_CN):$(AD_USR_PW) | grep $(GREP_ENV) $(MAIL_SUB)$*

test-pop3: test-pop3_0
test-pop3s: test-pop3_9
test-pop3_%: test-cfg_% test-lmtp_%
	docker run $(CURL_ENV) $(CURL_IMG) $(CURL_OPT) pop3$(cfg_s)://$(APP_NAME)/1 \
	--ssl --anyauth -k -u $(AD_USR_CN):$(AD_USR_PW) | grep $(GREP_ENV) $(MAIL_SUB)$*

test-http: test-http_9
test-http_%: test-cfg_%
	if [ $* -ge 3 ]; then \
	docker run $(CURL_ENV) $(CURL_IMG) $(CURL_OPT) http://$(APP_NAME) | grep $(GREP_ENV) $(WEB_TIT) \
	; fi

test-env:
	docker exec -it $(APP_NAME) env

test-logs:
	docker container logs $(APP_NAME)

test-sh:
	docker exec -it $(APP_NAME) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

test-diff:
	docker container diff $(APP_NAME)

test-sv:
	docker exec -it $(APP_NAME) sh -c 'sv status $$SVDIR/*'

test-debugtools:
	docker exec -it $(APP_NAME) apt-get update
	docker exec -it $(APP_NAME) apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping strace

test-htop: test-debugtools
	docker exec -it $(APP_NAME) htop

test-tls: #--starttls imap
	docker run --rm -it $(NET_ENV) drwetter/testssl.sh $(APP_NAME):993 || true

acme-destroy: ssl-destroy
	rm -f acme/*

acme/acme.json: $(APP_CERT)
	bin/gen-acme-json.sh $(AD_USR_CN)@$(AD_DOM) $(APP_FQDN) $(APP_KEY) $(APP_CERT) > $@
