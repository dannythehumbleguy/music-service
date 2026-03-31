include .env
export

.PHONY: cert cert-renew up down restart logs logs-navidrome logs-nginx status playlists

cert:
	docker compose down nginx
	docker compose run --rm -p 80:80 certbot certonly \
		--standalone \
		--email $(EMAIL) \
		--domain $(DOMAIN) \
		--agree-tos \
		--no-eff-email
	docker compose up -d nginx

cert-renew:
	docker compose down nginx
	docker compose run --rm -p 80:80 certbot renew
	docker compose up -d nginx

up:
	mkdir -p $(ND_MUSICFOLDER) $(ND_DATAFOLDER)
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

logs-navidrome:
	docker compose logs -f navidrome

logs-nginx:
	docker compose logs -f nginx

status:
	docker compose ps

playlists:
	./gen-playlists.sh
