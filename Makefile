
TAGNAME=wip

prod-build:
	docker image build --target prod-build --build-arg TAGNAME=$(TAGNAME) -t arch2code/ac2-dev:$(TAGNAME) -f Dockerfile .

test-build:
	docker image build --target test-build --build-arg TAGNAME=$(TAGNAME) --build-arg USERNAME=$(USER) --build-arg USER_UID=$(shell id -u) --build-arg USER_GID=$(shell id -g) -t arch2code/a2c-dev-test:$(TAGNAME) -f Dockerfile .

prod-build-vg:
	docker image build --target prod-build --build-arg TAGNAME=$(TAGNAME) -t arch2code/a2c-dev-vg:$(TAGNAME) -f Dockerfile-valgrind .

test-build-vg:
	docker image build --target test-build --build-arg TAGNAME=$(TAGNAME) --build-arg USERNAME=$(USER) --build-arg USER_UID=$(shell id -u) --build-arg USER_GID=$(shell id -g) -t arch2code/a2c-dev-vg-test:$(TAGNAME) -f Dockerfile-valgrind .

