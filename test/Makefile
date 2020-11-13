-include    *.mk

IMG_REPO ?= mlan/kopano
IMG_VER  ?= latest
_ver      = $(if $(findstring latest,$(1)),$(2),$(1)-$(2))
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

CURL_DBG ?=

TST_NAME ?= test
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
APPS_ENV ?= \
-e IMAPS_LISTEN=*:993 \
-e POP3S_LISTEN=*:995 \
-e ICALS_LISTEN=*:8443

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

test-all: test-up_0 test_1
	

test_%: test-up_% test-waitl_% test-logs_% test-mail_% test-down_%
	
test-up: test-up_1

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
	# recv: curl imap://app
	#
	#
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG)
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)
	sleep $(TST_W8L1)

test-up_2: test-up-net test-up-auth_2
	#
	#
	# test (1) ldap auth, sql db, web and mail send recv secure
	#
	# send: curl lmtp://app -> srv mysql://db & srv ldap://auth
	# recv: curl imap://app
	#
	#
	docker run -d $(DB_ENV) $(DB_VOL) $(DB_IMG)
	docker run -d $(APP_ENV) $(APP_VOL) $(IMG_REPO):$(call _ver,$(IMG_VER),core)

test-mail: test-mail_0
test-mail_%: test-lmtp_% test-waits_% test-pop3_% test-imap_%
	#
	#
	# test ($*) successful
	#
	#

test-logs_%:
	docker container logs $(APP_NAME) | grep 'docker-entrypoint.sh' || true

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
	| nc -C $(call _ip,$(APP_NAME)) 2003

test-imap: test-imap_0
test-imap_%:
	docker run -i --rm $(NET_ENV) curlimages/curl -s imap://$(APP_NAME)/inbox \
	-X "fetch 1 all" -u $(MAIL_US1):$(MAIL_PW1) | grep $(MAIL_SUB)$*

test-pop3: test-pop3_0
test-pop3_%:
	docker run -i --rm $(NET_ENV) curlimages/curl -s pop3://$(APP_NAME)/1 \
	-u $(MAIL_US1):$(MAIL_PW1) | grep $(MAIL_SUB)$*

$(TST_CRT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch -days $(TST_CRTD) \
		-subj "/CN=$(TST_SRV)" -key $(TST_KEY) -out $(TST_CRT)

$(TST_KEY): test/tmp
	openssl genrsa -out $(TST_KEY)

$(TST_ACME): $(TST_CRT)
	mkdir -p $(shell dirname $(TST_ACME))
	test/bin/gen-acme-json.sh $(TST_RADR)@$(TST_DOM) srv.$(TST_DOM) $(TST_KEY) $(TST_CRT) > $(TST_ACME)

test-cert-rm:
	rm $(TST_KEY) $(TST_CRT) $(TST_ACME)

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

test-cert-gen: $(TST_ACME)

test-tls-srv_%:
	$(eval tst_starttls := $(shell if [ $* != 465 ]; then echo --starttls smtp; fi ))
	docker run --rm -it --network $(TST_NET) drwetter/testssl.sh $(tst_starttls) $(TST_SRV):$* || true

test/tmp:
	mkdir -p test/tmp
