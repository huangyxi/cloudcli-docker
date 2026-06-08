#!/usr/bin/env bash

docker compose down

find workspace/ -mindepth 1 -maxdepth 1 -name '.*' ! -name '.gitignore' -exec rm -rf -- {} +
find claude/ -mindepth 1 -maxdepth 1 -type d -exec rm -rf -- {} +
find cloudcli-config/ -mindepth 1 -maxdepth 1 -name 'auth.db' -delete

docker compose up -d

for _ in {1..10}; do
	if [[ -f cloudcli-config/auth.db ]]; then
		break
	fi
	sleep 1
done

if [[ -f cloudcli-config/auth.db ]]; then
	scripts/init-auth.py cloudcli-config/auth.db
else
	echo "Timed out waiting for cloudcli-config/auth.db" >&2
	exit 1
fi
