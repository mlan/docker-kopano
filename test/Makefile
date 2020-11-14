-include    *.mk

IMG_REPO ?= mlan/kopano
IMG_VER  ?= latest
_ver      = $(if $(findstring latest,$(1)),$(2),$(1)-$(2))
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

CURL_DBG ?=

TST_NAME ?= test
SSL_KEYF ?= priv-key.pem
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
APP_IMAG ?=
APP_FQDN ?= $(APP_NAME).$(MAIL_DOM)
APP_VOL  ?=
APP_SSLD ?= /etc/kopano/ssl
APP_ENV  ?= $(NET_ENV) $(SQL_ENV) \
--name $(APP_NAME) \
--hostname $(APP_FQDN) \
-e MYSQL_HOST=$(DB_NAME) \
-e USER_PLUGIN=ldap \
-e LDAP_URI=ldap://$(AUT_NAME):389/ \
-e LDAP_SEARCH_BASE=$(LDAP_BAS) \
-e LDAP_USER_TYPE_ATTRIBUTE_VALUE=$(LDAP_UOB) \
-e LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=$(LDAP_GOU) \
-e IMAP_LISTEN=*:143 \
-e POP3_LISTEN=*:110 \
-e ICAL_LISTEN=*:8080 \
-e DISABLED_FEATURES=
APPS_ENV ?= $(APP_ENV) \
-e IMAPS_LISTEN=*:993 \
-e POP3S_LISTEN=*:995 \
-e ICALS_LISTEN=*:8443
APPF_ENV ?= $(APPS_ENV) \
-e SSL_CERTIFICATE_FILE=$(APP_SSLD)/$(SSL_CRTF) \
-e SSL_PRIVATE_KEY_FILE=$(APP_SSLD)/$(SSL_KEYF)
APPA_ENV ?= $(APPS_ENV) \
-e ACME_FILE=/$(TST_ACME) \
-v $(shell pwd)/$(TST_ACMD):/$(TST_ACMD)

DB_NAME  ?= db
DB_IMG   ?= mariadb
DB_FQDN  ?= $(DB_NAME).$(MAIL_DOM)
DB_VOL   ?=
DB_ENV   ?= $(NET_ENV) $(SQL_ENV) \
--name $(DB_NAME) \
--hostname $(DB_FQDN) \
-e MYSQL_ROOT_PASSWORD=$(SQL_PASS)

AUT_NAME ?= auth
AUT_IMG  ?= mlan/openldap
AUT_FQDN ?= $(AUT_NAME).$(MAIL_DOM)
AUT_VOL  ?=
AUT_ENV  ?= $(NET_ENV) \
--name $(AUT_NAME) \
--hostname $(AUT_FQDN) \

TST_W8S1 ?= 1
TST_W8S2 ?= 80
TST_W8L1 ?= 20
TST_W8L2 ?= 120

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

test-all: test-up_0 test_1 test_2 test_3
	

test_%: test-up_% test-waitl_% test-logs_% test-service_% test-down_%
	

test-up_0: test-up-net
	#
	#
	# test (0) run without envvars (is there smoke?)
	#
	# run containers see if there are logs and stop.
	#
	#
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)
	sleep $(TST_W8L1)
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'
	docker rm -fv $(APP_NAME)
	sleep $(TST_W8S1)
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),full)
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
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG)
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)
	sleep $(TST_W8L1)

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
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG)
	docker run -d $(APPF_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)
	docker cp $(TST_SSLD)/. $(APP_NAME):$(APP_SSLD)
	docker exec -i $(APP_NAME) chown -R kopano: $(APP_SSLD)

test-up_3: test-up-net test-up-auth_3 $(TST_ACME)
	#
	#
	# test (3) ldap auth, sql db, mail send recv secure using acme cert
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl pop3s://app
	# recv: curl imaps://app
	#
	#
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG)
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
	-docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh'

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
	| nc -C $(call _ip,$(APP_NAME)) 2003 > /dev/null
	case $* in [1-3]) sleep $(TST_W8S1);; [4-9]) sleep $(TST_W8S2);; esac

test-cfg_%:
	$(eval cfg_s := $(shell [ $* -ge 2 ] && echo s))
	$(eval cfg_s := $(shell [ $* -ge 2 ] && echo s))

# Note: cannot use prereq also in a proper target since it will change the
# prereq order, eg. avoid the "3" in test-imaps: test-imap_3
test-imap: test-imap_0
test-imaps: test-imap_9
test-imap_%: test-cfg_% test-lmtp_%
	docker run -i --rm $(NET_ENV) curlimages/curl imap$(cfg_s)://$(APP_NAME)/inbox \
	-s --ssl --anyauth -k -X "fetch 1 all" -u $(MAIL_US1):$(MAIL_PW1) | grep --color=always $(MAIL_SUB)$*

test-pop3: test-pop3_0
test-pop3s: test-pop3_9
test-pop3_%: test-cfg_% test-lmtp_%
	docker run -i --rm $(NET_ENV) curlimages/curl pop3$(cfg_s)://$(APP_NAME)/1 \
	-s --ssl --anyauth -k -u $(MAIL_US1):$(MAIL_PW1) | grep --color=always $(MAIL_SUB)$*

test-http: test-http_9
test-http_%: test-cfg_%
	if [ $* -ge 3 ]; then \
	docker run -i --rm $(NET_ENV) curlimages/curl http://$(APP_NAME) -s | grep --color=always $(WEB_TIT) \
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

test-cert-gen: $(TST_ACME)

test-cert-rm:
	rm $(TST_KEY) $(TST_CRT) $(TST_ACME)

$(TST_ACME): $(TST_ACMD) $(TST_CERT)
	bin/gen-acme-json.sh $(MAIL_US1)@$(MAIL_DOM) $(APP_FQDN) $(TST_KEY) $(TST_CERT) > $(TST_ACME)

$(TST_CERT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch -days $(SSL_CRTD) \
	-subj "/CN=$(APP_FQDN)" -key $(TST_KEY) -out $@

$(TST_KEY): $(TST_SSLD)
	openssl genrsa -out $@

$(TST_SSLD) $(TST_ACMD):
	mkdir -p $@