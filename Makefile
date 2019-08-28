-include    *.mk

BLD_ARG  ?= --build-arg DIST=ubuntu --build-arg REL=18.04 --build-arg ARCH=amd64
IMG_REPO ?= mlan/kopano
IMG_VER  ?= $(shell assets/kopano-webaddr.sh -VV)
IMG_CMD  ?= /bin/bash

CNT_NAME ?= kopano-default
CNT_PORT ?= -p 80:80
CNT_ENV  ?=
CNT_VOL  ?=

.PHONY: build build-all bulid-core build-full build-debugtools \
	variables push shell exec run run-fg stop rm-container rm-image release logs

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

build: Dockerfile
	docker build $(BLD_ARG) --target kopano-full -t $(IMG_REPO)\:$(IMG_VER) .

build-all: build-core build-full build-debugtools

build-core: Dockerfile
	docker build $(BLD_ARG) --target kopano-core \
	-t $(IMG_REPO)\:$(IMG_VER)-core \
	-t $(IMG_REPO)\:latest-core .

build-full: Dockerfile
	docker build $(BLD_ARG) --target kopano-full \
	-t $(IMG_REPO)\:$(IMG_VER) \
	-t $(IMG_REPO)\:$(IMG_VER)-full \
	-t $(IMG_REPO)\:latest \
	-t $(IMG_REPO)\:latest-full .

build-debugtools: Dockerfile
	docker build $(BLD_ARG) --target kopano-debugtools \
	-t $(IMG_REPO)\:$(IMG_VER)-debugtools \
	-t $(IMG_REPO)\:latest-debugtools .

push:
	docker push $(IMG_REPO)\:$(IMG_VER)

version:
	assets/kopano-webaddr.sh -VV

shell:
	docker run --rm --name $(CNT_NAME)-$(CNT_INST) -i -t $(CNT_PORT) $(CNT_VOL) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER) $(IMG_CMD)

exec:
	docker exec -it $(CNT_NAME) $(IMG_CMD)

run-fg:
	docker run --rm --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

run:
	docker run --rm -d --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

logs:
	docker container logs $(CNT_NAME)

stop:
	docker stop $(CNT_NAME)

rm-container:
	docker rm $(CNT_NAME)

rm-image:
	docker image rm $(IMG_REPO):$(IMG_VER)

release: build
	make push -e IMG_VER=$(IMG_VER)

