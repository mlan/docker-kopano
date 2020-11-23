-include    *.mk

IMG_REPO ?= mlan/kopano
IMG_VER  ?= latest
_ver      = $(if $(findstring latest,$(1)),$(2),$(1)-$(2))
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

TST_NAME ?= test
SSL_KEYF ?= priv_key.pem
SSL_CRTF ?= cert.pem
SSL_CRTD ?= 30
SSL_ACMF ?= acme.json
TST_SSLD ?= ssl
TST_ACMD ?= acme
TST_KEY  ?= $(TST_SSLD)/$(SSL_KEYF)
TST_CERT ?= $(TST_SSLD)/$(SSL_CRTF)
TST_ACME ?= $(TST_ACMD)/$(SSL_ACMF)

NET_NAME ?= test-net
NET_ENV  ?= --network $(NET_NAME)

LDAP_BAS ?= dc=example,dc=com
LDAP_UOU ?= users
LDAP_UOB ?= posixAccount
LDAP_GOU ?= groups
LDAP_FOU ?= "(&(objectclass=$(LDAP_UOB))(mail=%s))"
LDAP_FPW ?= "(&(objectclass=$(LDAP_UOB))(uid=%u))"
LDAP_APW ?= uid=user

MAIL_DOM ?= example.com
MAIL_US1 ?= hero
MAIL_PW1 ?= enigma
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
APP_IMG  ?=
APP_FQDN ?= $(APP_NAME).$(MAIL_DOM)
APP_VOL  ?=
APP_SSLD ?= /etc/kopano/ssl
APP_SLOG ?= 7
APP_ALOG ?= 6
APP_ENV  ?= $(NET_ENV) $(SQL_ENV) \
--name $(APP_NAME) \
--hostname $(APP_FQDN) \
-e MYSQL_HOST=$(DB_NAME) \
-e USER_PLUGIN=ldap \
-e LDAP_URI=ldap://$(AUT_NAME):389/ \
-e LDAP_SEARCH_BASE=$(LDAP_BAS) \
-e LDAP_USER_TYPE_ATTRIBUTE_VALUE=$(LDAP_UOB) \
-e LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=$(LDAP_GOU) \
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
APPF_ENV ?= $(APPS_ENV) \
-v $(shell pwd)/$(TST_SSLD):/$(APP_SSLD)
APPA_ENV ?= $(APPS_ENV) \
-v $(shell pwd)/$(TST_ACMD):/$(TST_ACMD)

#-p "127.0.0.1:2003:2003"

AUT_NAME ?= auth
AUT_IMG  ?= mlan/openldap
AUT_FQDN ?= $(AUT_NAME).$(MAIL_DOM)
AUT_VOL  ?=
AUT_ENV  ?= $(NET_ENV) \
--name $(AUT_NAME) \
--hostname $(AUT_FQDN)

CURL_OPT ?= -s -v
CURL_IMG ?= curlimages/curl
CURL_ENV ?= $(NET_ENV) \
-i --rm

DB_NAME  ?= db
DB_IMG   ?= mariadb
DB_FQDN  ?= $(DB_NAME).$(MAIL_DOM)
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
	# test (0) run without envvars (is there smoke?)
	#
	# run containers see if there are logs and stop.
	#
	#
	docker run -d --name $(APP_NAME) $(IMG_REPO):$(call _ver,$(IMG_VER),core)
	sleep $(TST_W8L1)
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'
	docker rm -fv $(APP_NAME)
	sleep $(TST_W8S1)
	docker run -d --name $(APP_NAME) $(IMG_REPO):$(call _ver,$(IMG_VER),full)
	sleep $(TST_W8L1)
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'
	docker rm -fv $(APP_NAME)
	sleep $(TST_W8S1)
	#
	#
	# test (0) successful
	#
	#

test-up_1: test-up-net test-up-auth_1
	#
	#
	# test (1) ldap auth, sql db, and mail send recv
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3://app
	# recv: curl imap://app
	#
	#
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG) $(DB_CMD)
	sleep $(TST_W8L1)
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)

test-up_2: test-up-net test-up-auth_2 $(TST_CERT)
	#
	#
	# test (2) ldap auth, sql db, mail send recv secure using pem cert files
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3s://app
	# recv: curl imaps://app
	#
	#
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG) $(DB_CMD)
	sleep $(TST_W8L1)
	docker run -d $(APPF_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)

test-up_3: test-up-net test-up-auth_3 $(TST_ACME)
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
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG) $(DB_CMD)
	sleep $(TST_W8L1)
	docker run -d $(APPA_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),full)

test-up: test-up_1

test-service: test-service_0

test-service_%: test-pop3_% test-imap_% test-http_%
	#
	#
	# test ($*) successful
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
	docker rm -fv $(APP_NAME) $(DB_NAME) $(AUT_NAME) 2>/dev/null || true
	if [ $* -ge 0 ]; then sleep $(TST_W8S1); fi

test-up-auth_%:
	docker run -d $(AUT_ENV) $(AUT_VOL) $(AUT_IMG)
	sleep $(TST_W8L1)
	printf "dn: ou=$(LDAP_UOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_UOU)\n\ndn: ou=$(LDAP_GOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_GOU)\n\ndn: uid=$(MAIL_US1),ou=$(LDAP_UOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: top\nobjectClass: inetOrgPerson\nobjectClass: $(LDAP_UOB)\ncn: $(MAIL_US1)\nsn: $(MAIL_US1)\nuid: $(MAIL_US1)\nmail: $(MAIL_US1)@$(MAIL_DOM)\nuidNumber: 1234\ngidNumber: 1234\nhomeDirectory: /home/$(MAIL_US1)\nuserPassword: $(MAIL_PW1)\n" \
	| docker exec -i $(AUT_NAME) ldap modify

test-lmtp: test-lmtp_0
test-lmtp_%:
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(MAIL_US1)@$(MAIL_DOM)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(MAIL_US1)@$(MAIL_DOM)>\nDate: $$(date)\nSubject: $(MAIL_SUB)$*\n$(MAIL_MSG)$*\n.\nQUIT\n"\
	| nc -C $(call _ip,$(APP_NAME)) 2003 # > /dev/null
#	| nc -C localhost 2003 # > /dev/null
	case $* in [1-3]) sleep $(TST_W8S1);; [4-9]) sleep $(TST_W8S2);; esac

test-cfg_%:
	$(eval cfg_s := $(shell [ $* -ge 2 ] && echo s))
	$(eval cfg_s := $(shell [ $* -ge 2 ] && echo s))

# Note: cannot use prereq also in a proper target since it will change the
# prereq order, eg. avoid the "3" in test-imaps: test-imap_3
test-imap: test-imap_0
test-imaps: test-imap_9
test-imap_%: test-cfg_% test-lmtp_%
	docker run $(CURL_ENV) $(CURL_IMG) $(CURL_OPT) imap$(cfg_s)://$(APP_NAME)/inbox \
	--ssl --anyauth -k -X "fetch 1 all" -u $(MAIL_US1):$(MAIL_PW1) | grep $(GREP_ENV) $(MAIL_SUB)$*

test-pop3: test-pop3_0
test-pop3s: test-pop3_9
test-pop3_%: test-cfg_% test-lmtp_%
	docker run $(CURL_ENV) $(CURL_IMG) $(CURL_OPT) pop3$(cfg_s)://$(APP_NAME)/1 \
	--ssl --anyauth -k -u $(MAIL_US1):$(MAIL_PW1) | grep $(GREP_ENV) $(MAIL_SUB)$*

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

test-ssl-gen: $(TST_ACME)

test-ssl-rm:
	rm -rf $(TST_SSLD) $(TST_ACMD)
#	rm $(TST_KEY) $(TST_CRT) $(TST_ACME)

$(TST_ACME): $(TST_ACMD) $(TST_CERT)
	bin/gen-acme-json.sh $(MAIL_US1)@$(MAIL_DOM) $(APP_FQDN) $(TST_KEY) $(TST_CERT) > $(TST_ACME)

$(TST_CERT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch -days $(SSL_CRTD) \
	-subj "/CN=$(APP_FQDN)" -key $(TST_KEY) -out $@

$(TST_KEY): $(TST_SSLD)
	openssl genrsa -out $@
	chmod a+r $@

$(TST_SSLD) $(TST_ACMD):
	mkdir -p $@
