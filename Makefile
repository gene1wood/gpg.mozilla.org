COMPOSE_CMD := "up"
DUMP_URL := "http://keys.niif.hu/keydump/"
VOLUME := "gpgmozillaorg_sks"

all: docker-compose.yml
	docker-compose -f docker-compose.yml $(COMPOSE_CMD)

build: */Dockerfile
	docker-compose -f docker-compose.yml build

rebuild:
	@echo Rebuilding/updating images
	docker-compose -f docker-compose.yml build --pull --no-cache

install:
	@echo ensuring docker volume is present
	docker volume create sks
	@echo Setting permissions
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 gpgmozillaorg_sks-db chown -R sks:sks /var/sks

	@echo Getting dump from $(DUMP_URL) (see sources at https://bitbucket.org/skskeyserver/sks-keyserver/wiki/KeydumpSources)
	@echo This will take forever. How much coffee can you drink before it\'s done? tic-tac-tic-tac...
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 -w /var/sks/dump gpgmozillaorg_sks-db \
		wget -crp -e robots=off -l1 --no-parent --cut-dirs=3 -nH -A pgp,txt $(DUMP_URL)

	@echo Decompressing files...
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 -w /var/sks/dump gpgmozillaorg_sks-db \
	    	bzip2 -d *bz2

	@echo Creating KDB...
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 -w /var/sks/ gpgmozillaorg_sks-db \
	    	sks build
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 -w /var/sks/ gpgmozillaorg_sks-db \
	    	sks merge dump/*pgp

	@echo Creating PTree...
	docker run -ti --mount source=$(VOLUME),target=/var/sks -u 0 -w /var/sks/ gpgmozillaorg_sks-db \
	    	sks pbuild

update-web:
	docker run -ti --mount source=$(VOLUME),target=/var/sks -w /var/sks/ --name gpgmozillaorg_tmp gpgmozillaorg_sks-db true
	docker cp sks-db/etc/web/. gpgmozillaorg_tmp:/var/sks/web/
	docker rm gpgmozillaorg_tmp

.PHONY: all
