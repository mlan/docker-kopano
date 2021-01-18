# Makefile
#
# build
#

-include    *.mk

#BLD_ARG  ?= --build-arg DIST=ubuntu --build-arg REL=18.04 --build-arg ARCH=i386
BLD_ARG  ?=
BLD_REPO ?= mlan/kopano
BLD_VER  ?= latest
BLD_TGT  ?= full

SRC_CMD  ?= src/kopano/bin/kopano-webaddr.sh -VV
SRC_VER  ?= $(shell $(SRC_CMD))

TST_REPO ?= $(BLD_REPO)
TST_VER  ?= $(BLD_VER)
TST_ENV  ?= -C test
TST_TGTE ?= $(addprefix test-,all diff down env htop imap lmtp logs mail pop3 pull sh sv up)
TST_TGTI ?= test_% test-up_%
export TST_REPO TST_VER
_version  = $(if $(findstring $(BLD_TGT),$(1)),\
$(if $(findstring latest,$(2)),latest $(1) $(SRC_VER) $(1)-$(SRC_VER),$(2) $(1)-$(2)),\
$(if $(findstring latest,$(2)),$(1) $(1)-$(SRC_VER),$(1)-$(2)))

build-all: build_core build_full

build: build_$(BLD_TGT)

build_%: Dockerfile
	docker build $(BLD_ARG) --target $* \
	$(addprefix --tag $(BLD_REPO):,$(call _version,$*,$(BLD_VER))) .

version:
	$(SRC_CMD)

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

prune:
	docker image prune -f

clean:
	docker images | grep $(BLD_REPO) | awk '{print $$1 ":" $$2}' | uniq | xargs docker rmi

$(TST_TGTE):
	${MAKE} $(TST_ENV) $@

$(TST_TGTI):
	${MAKE} $(TST_ENV) $@
