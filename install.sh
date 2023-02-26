#!/usr/bin/env nix-shell
#!nix-shell -i bash -p dig jq mkcert nssTools

NETWORK_NAME="traefik"
DOMAIN="this.test"

echo "==> 📜 installing mkcert certificates for ${DOMAIN}..."
mkcert -install
mkcert -cert-file certs/local.crt -key-file certs/local.key "${DOMAIN}" "*.${DOMAIN}"
echo "==> ✅ installed certificates"

echo "==> 🤔 checking dnsmasq config..."
if [[ $(dig +short "$DOMAIN") == "127.0.0.1" ]]; then
	echo "✅ managed to resolve $DOMAIN to localhost"
else
	echo "❌ failed to resolve $DOMAIN. Please check your system-wide dnsmasq config."
	exit 1
fi

if [[ $(command -v docker) ]]; then
	if [[ $(docker network inspect "$NETWORK_NAME" 2>/dev/null | jq ". | length") -gt 0 ]]; then
		echo "==> 🐳 $NETWORK_NAME network already exists"
	else
		echo "==> 🐳 creating $NETWORK_NAME network..."
		docker network create "$NETWORK_NAME"
		echo "==> ✅ created $NETWORK_NAME network"
	fi

	echo "==> 🐳 starting docker containers..."
	docker compose up -d
	echo "==> ✅ started docker containers"
else
	echo "==> ❌ docker not found"
fi
