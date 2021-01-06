-include    *.mk .env .init.env

srv_list ?= auth app db mta
curl_dbg ?= -v -s
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

.PHONY:

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

test: all-test_quiet mta-test_smtp

init: up auth-init db-init mta-init app-init

ps:
	docker-compose ps

up:
	docker-compose up -d

down:
	docker-compose down

destroy: auth-gui-down all-destroy_smime
	docker-compose down -v

config:
	docker-compose config

logs:
	docker-compose logs --tail 10

images:
	docker-compose images

$(addsuffix -up,$(srv_list)):
	docker-compose up -d $(patsubst %-up,%,$@)

$(addsuffix -down,$(srv_list)):
	docker-compose rm -s $(patsubst %-down,%,$@)

$(addsuffix -restart,$(srv_list)):
	docker-compose restart $(patsubst %-restart,%,$@)

$(addsuffix -renew,$(srv_list)):
	docker-compose rm -s $(patsubst %-renew,%,$@)
	docker-compose up -d $(patsubst %-renew,%,$@)

$(addsuffix -top,$(srv_list)):
	docker-compose top $(patsubst %-top,%,$@)

$(addsuffix -logs,$(srv_list)):
	docker-compose logs $(patsubst %-logs,%,$@)

$(addsuffix -pull,$(srv_list)):
	docker-compose pull $(patsubst %-pull,%,$@)

$(addsuffix -sh,$(srv_list)):
	docker-compose exec $(patsubst %-sh,%,$@) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

$(addsuffix -env,$(srv_list)):
	docker-compose exec $(patsubst %-env,%,$@) env

$(addsuffix -sv,$(srv_list)):
	docker-compose exec $(patsubst %-sv,%,$@) sh -c 'sv status $$SVDIR/*'

$(addsuffix -diff,$(srv_list)):
	docker container diff $(COMPOSE_PROJECT_NAME)_$(patsubst %-diff,%,$@)_1

wait_%:
	sleep $*

web:
	firefox localhost:8008 &

auth-init: wait_11 auth-mod_conf auth-add_schema auth-add_data auth-add_sto

define LDIF_MOD_CONF
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcPasswordHash
olcPasswordHash: {CRYPT}

dn: cn=config
changetype: modify
add: olcPasswordCryptSaltFormat
olcPasswordCryptSaltFormat: $$6$$%.16s

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: cn,ou,uid,mail eq
endef
export LDIF_MOD_CONF

define LDIF_ADD_DATA
dn: ou=$(LDAP_USEROU),$(LDAP_BASE)
changetype: add
ou: $(LDAP_USEROU)
objectClass: top
objectClass: organizationalUnit

dn: ou=$(LDAP_GROUPOU),$(LDAP_BASE)
changetype: add
ou: $(LDAP_GROUPOU)
objectClass: top
objectClass: organizationalUnit

dn: cn=$(LDAP_TEST_GROUP),ou=$(LDAP_GROUPOU),$(LDAP_BASE)
changetype: add
cn: $(LDAP_TEST_GROUP)
objectClass: top
objectClass: groupOfNames
objectClass: kopano-group
member: uid=$(LDAP_TEST_ADMIN),ou=$(LDAP_USEROU),$(LDAP_BASE)
member: uid=$(LDAP_TEST_USER),ou=$(LDAP_USEROU),$(LDAP_BASE)
mail: $(LDAP_TEST_GROUP)@$(MAIL_DOMAIN)

dn: uid=$(LDAP_TEST_ADMIN),ou=$(LDAP_USEROU),$(LDAP_BASE)
changetype: add
cn: $(LDAP_TEST_ADMIN)
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(LDAP_TEST_ADMIN)
uid: $(LDAP_TEST_ADMIN)
mail: $(LDAP_TEST_ADMIN)@$(MAIL_DOMAIN)
userPassword: $(LDAP_TEST_ADMINPW)
telephoneNumber: 0123 987654321
title: System Admin
kopanoAccount: 1
kopanoAdmin: 1
kopanoEnabledFeatures: imap
kopanoEnabledFeatures: pop3

dn: uid=$(LDAP_TEST_USER),ou=$(LDAP_USEROU),$(LDAP_BASE)
changetype: add
cn: $(LDAP_TEST_USER)
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(LDAP_TEST_USER)
uid: $(LDAP_TEST_USER)
mail: $(LDAP_TEST_USER)@$(MAIL_DOMAIN)
userPassword: $(LDAP_TEST_USERPW)
telephoneNumber: 0123 123456789
title: First User
kopanoAccount: 1
kopanoEnabledFeatures: imap
kopanoEnabledFeatures: pop3
endef
export LDIF_ADD_DATA

define LDIF_ADD_STO
dn: uid=$(LDAP_TEST_SHR),ou=$(LDAP_USEROU),$(LDAP_BASE)
changetype: add
cn: $(LDAP_TEST_SHR)
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(LDAP_TEST_SHR)
uid: $(LDAP_TEST_SHR)
mail: $(LDAP_TEST_SHR)@$(MAIL_DOMAIN)
kopanoAccount: 1
kopanoSharedStoreOnly: 1

dn: uid=$(LDAP_TEST_PUB),ou=$(LDAP_USEROU),$(LDAP_BASE)
changetype: add
cn: $(LDAP_TEST_PUB)
objectClass: top
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(LDAP_TEST_PUB)
uid: $(LDAP_TEST_PUB)
mail: $(LDAP_TEST_PUB)@$(MAIL_DOMAIN)
kopanoAccount: 1
kopanoHidden: 1
kopanoSharedStoreOnly: 1
kopanoResourceType: publicStore:Public Stores/public

endef
export LDIF_ADD_STO

auth-mod_conf:
	echo "$$LDIF_MOD_CONF" | docker-compose exec -T auth ldap modify

auth-add_data:
	echo "$$LDIF_ADD_DATA" | docker-compose exec -T auth ldap modify

auth-add_sto:
	echo "$$LDIF_ADD_STO" | docker-compose exec -T auth ldap modify

auth-add_schema:
	docker-compose exec app zcat /usr/share/doc/kopano/kopano.ldif.gz \
	| docker-compose exec -T auth ldapadd -H ldapi://%2Fvar%2Frun%2Fopenldap%2Fldapi/ -Y EXTERNAL

auth-show_conf:
	docker-compose exec auth ldap search -b cn=config "(cn=config)"
	docker-compose exec auth ldap search -b cn=config olcDatabase={-1}frontend
	docker-compose exec auth ldap search -b cn=config olcDatabase={1}mdb

auth-show_data:
	docker-compose exec auth ldap search -b "$(LDAP_BASE)"

auth-show_cat0:
	docker-compose exec auth slapcat -n0

auth-show_cat1:
	docker-compose exec auth slapcat -n1

auth-gui-up:
	docker run -d --name auth-gui --network demo_backend \
	-p 127.0.0.1:8001:80 -e PHPLDAPADMIN_LDAP_HOSTS=auth \
	-e PHPLDAPADMIN_HTTPS=false osixia/phpldapadmin || true
	sleep 2
	firefox localhost:8001 &

auth-gui-down:
	docker rm -f auth-gui || true

mta-init:

mta-bayes:
	docker-compose exec mta sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis: /var/amavis/.spamassassin && rm -rf bayesian.database'

mta-test_smtp:
	printf "From: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! You can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(LDAP_TEST_USER)@$(MAIL_DOMAIN) $(curl_dbg)

mta-test_smtps:
	printf "From: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTPS test message\n\nGreat news! You can receive secure email.\n" \
	| curl smtps://localhost -T - --mail-from test@example.biz -k \
	-u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) \
	--mail-rcpt $(LDAP_TEST_USER)@$(MAIL_DOMAIN) $(curl_dbg)

mta-test_smtp2:
	printf "From: A info tester <test-info@example.biz>\nTo: <$(LDAP_TEST_USER)-info@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message \n\nGreat news! $(LDAP_TEST_USER)-info@$(MAIL_DOMAIN) can also receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(LDAP_TEST_USER)@$(MAIL_DOMAIN) $(curl_dbg)

mta-test_shared: all-test_quiet
	printf "From: A tester <test@example.biz>\nTo: <$(LDAP_TEST_SHR)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! A shared store can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(LDAP_TEST_SHR)@$(MAIL_DOMAIN) $(curl_dbg)

mta-test_public: all-test_quiet
	printf "From: A tester <test@example.biz>\nTo: <$(LDAP_TEST_PUB)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! A public store can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(LDAP_TEST_PUB)@$(MAIL_DOMAIN) $(curl_dbg)

mta-razor:
	docker-compose exec mta run amavis_register_razor

mta-apk_list:
	docker-compose exec mta /bin/sh -c 'for pkg in $$(apk info 2>/dev/null); do printf "%9s  %s\n" $$(apk info -s $$pkg 2>/dev/null | sed -n "2{p;q}") $$pkg; done | sort'

mta-quarantine_list:
	docker-compose exec mta amavis-ls

mta-freshclam_nodns:
	docker-compose exec mta freshclam --no-dns

mta-clamdtop:
	docker-compose exec mta clamdtop

mta-debugtools:
	docker-compose exec mta apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils strace

mta-htop: mta-debugtools
	docker-compose exec mta htop

mta-encrypt:
	$(eval secret := $(shell whiptail --backtitle "doveadm pw" --title "encrypt password" --inputbox "password" 8 78 secret 3>&1 1>&2 2>&3))
	docker-compose exec mta doveadm pw -p $(secret)

mta-show_doveconf:
	docker-compose exec mta doveconf -n

mta-show_postconf:
	docker-compose exec mta postconf -n

mta-show_mailq:
	docker-compose exec mta mailq

mta-flush_mailq:
	docker-compose exec mta postqueue -f

mta-hostaddr:
	$(eval myhost := $(call _ip,$(COMPOSE_PROJECT_NAME)_mta_1))

mta-test_auth:
	docker-compose exec mta doveadm auth test $(LDAP_TEST_USER) $(LDAP_TEST_USERPW)

mta-test_imap: mta-hostaddr
	curl imap://$(myhost) -X CAPABILITY
	curl imap://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW)

mta-test_rimap:
	docker-compose exec mta curl imap://app -X CAPABILITY
	docker-compose exec mta curl imap://app -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW)

mta-test_ldap: mta-debugtools
	docker-compose exec mta ldapsearch -H ldap://auth:389 -xLLL -s base namingContexts

db-init:

db-test:
	docker-compose exec db mysqlshow -u $(MYSQL_USER) $(MYSQL_DATABASE) -p$(MYSQL_PASSWORD)

db-gui-up:
	docker run -d --name db-gui --network demo_backend \
	-p 127.0.0.1:8002:80 -e PMA_HOST=db \
	phpmyadmin/phpmyadmin || true
	sleep 2
	firefox localhost:8002 &

db-gui-down:
	docker rm -f db-gui || true

app-init: #wait_92 app-public_store

app-debugtools:
	docker-compose exec app apt-get update
	docker-compose exec app apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping dnsutils strace

app-htop: app-debugtools
	docker-compose exec app htop

app-man_server:
	docker-compose exec app man kopano-server.cfg

app-man_ldap:
	docker-compose exec app man kopano-ldap.cfg

app-hostaddr:
	$(eval myhost := $(call _ip,$(COMPOSE_PROJECT_NAME)_app_1))

app-test_smtp: mta-test_smtp

app-test_lmtp: app-hostaddr
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A LMTP test message from me to you\n\nDelete me, please \n.\nQUIT\n" | nc -C $(myhost) 2003

app-test_all: all-test_muted app-test_imap app-test_pop3 app-test_ical app-test_imaps app-test_pop3s app-test_icals

app-test_imap: app-hostaddr
	curl imap://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_imaps: app-hostaddr
	curl imaps://$(myhost) -k -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_pop3: app-hostaddr
	curl pop3://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_pop3s: app-hostaddr
	curl pop3s://$(myhost) -k -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_ical: app-hostaddr
	curl http://$(myhost):8080 -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_icals: app-hostaddr
	curl https://$(myhost):8443 -k -u $(LDAP_TEST_USER):$(LDAP_TEST_USERPW) $(curl_dbg)

app-test_tls: app-hostaddr
	docker run --rm -it --network demo_backend drwetter/testssl.sh app:993 || true

app-show_user1:
	docker-compose exec app kopano-admin --details $(LDAP_TEST_USER)

app-show_user2: app-debugtools
	docker-compose exec app ldapsearch -H ldap://auth:389 -xLLL -b $(LDAP_BASE) '*'

app-show_sync:
	docker-compose exec app z-push-top

app-create_store:
	docker-compose exec app kopano-admin --create-store $(LDAP_TEST_USER)

app-public_store:
	docker-compose exec app kopano-storeadm -P

$(addprefix app-parms_,archiver dagent gateway ical ldap search server spamd spooler):
	docker-compose exec app run list_parms $(patsubst app-parms_%,%,$@)

app-create_smime: all-create_smime ssl/ca.crt
	docker cp ssl/ca.crt $$(docker-compose ps -q app):/usr/local/share/ca-certificates/$(MAIL_DOMAIN)_CA.crt
	docker-compose exec app update-ca-certificates

all-test_quiet:
	$(eval curl_dbg := -s -S )

all-test_muted:
	$(eval curl_dbg := -s -S >/dev/null || true)

all-create_smime: ssl/$(LDAP_TEST_USER).smime.p12

all-destroy_smime:
	rm -rf ssl

#.PRECIOUS: %.key %.crt %.smime.crt

%.p12: %.crt
	openssl pkcs12 -export -in $< -inkey $*.key -out $@ \
	-passout pass:$(LDAP_TEST_USERPW)

%.csr: %.key
	openssl req -new -key $< -out $@ \
	-subj "/O=$(MAIL_DOMAIN)/CN=$(LDAP_TEST_USER)/emailAddress=$(LDAP_TEST_USER)@$(MAIL_DOMAIN)"

%.smime.crt: %.smime.csr ssl/ca.crt
	openssl x509 -req -in $< -CA $(@D)/ca.crt -CAkey $(@D)/ca.key -out $@ \
	-setalias "Self Signed SMIME" -addtrust emailProtection \
	-addreject clientAuth -addreject serverAuth -trustout \
	-CAcreateserial

%.crt: %.key
	openssl req -x509 -batch -key $< -out $@ \
	-subj "/O=$(MAIL_DOMAIN)"

%.key: ssl
	openssl genrsa -out $@
	chmod a+r $@

ssl:
	mkdir -p $@
