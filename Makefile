-include    *.mk

#BLD_ARG  ?= --build-arg DIST=ubuntu --build-arg REL=18.04 --build-arg ARCH=i386
BLD_ARG  ?=
BLD_REPO ?= mlan/kopano
BLD_VER  ?= latest
BLD_TGT  ?= full
SRC_VER  ?= $(shell src/docker/bin/kopano-webaddr.sh -VV)

_version  = $(if $(findstring $(BLD_TGT),$(1)),$(2),$(if $(findstring latest,$(2)),$(1),$(1)-$(2)))

.PHONY:

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

build-all: build_core build_full build_debugtools

build: build_$(BLD_TGT)

build_%: Dockerfile
	docker build $(BLD_ARG) --target $* \
	-t $(BLD_REPO):$(call _version,$*,$(BLD_VER)) \
	-t $(BLD_REPO):$(call _version,$*,$(SRC_VER)) .

version:
	src/docker/bin/kopano-webaddr.sh -VV

prune:
	docker image prune

clean:
	docker images | grep $(BLD_REPO) | awk '{print $$1 ":" $$2}' | uniq | xargs docker rmi
