# Traefik Local for Nix

Set up a local Traefik web proxy with DNS resolution on all \*.lan and \*.test domains.

Also sets up a local trusted Root CA and create a TLS certificate for using HTTPS in local (shout out to [mkcert](https://github.com/FiloSottile/mkcert)).

This guide is for macOS, but will work on Linux with minor modifications.

## 0. Prerequisites

- [Docker](https://docs.docker.com/docker-for-mac/install/)

## 1. Setup resolvers

Enable the dnsmasq service, pointing to your localhost.

```nix
  services = {
    dnsmasq = {
      enable = true;
      addresses."test" = "127.0.0.1";
      addresses."lan" = "127.0.0.1";
      bind = "127.0.0.1";
    };
  };
```

To verify this worked, `cat /etc/resolver/test` should return:

```
port 53
nameserver 127.0.0.1
```

and `ping this.test` should get a response from `127.0.0.1`

## 2. Set up a local Root CA, and prepare certificates

We're using `nix-shell` here, since these are not runtime dependencies.

```sh
nix-shell -p mkcert nssTools

# Setup the local Root CA
mkcert -install

# Local Root CA files are located under ~/Library/Application\ Support/mkcert
# Look at https://github.com/FiloSottile/mkcert is you need instructions to install them on another device

# Create a local TLS certificate
# You could add any domain you need ending by .lan or .test
# *.this.test will create a wildcard certificate so any subdomain in the form like.this.test will also work.
# Unfortunately you cannot create *.test wildcard certificate your browser will not allow it.
mkcert -cert-file certs/local.crt -key-file certs/local.key "this.test" "*.this.test" "this.lan" "*.this.lan"
```

## 3. Set up a Traefik container with HTTPS

```sh
# Clone this repository
git clone https://github.com/nekowinston/traefik-local-nix.git
cd traefik-local/

# Create an external network docker, all future containers
# which need to be exposed by domain name should use this network
docker network create docker

# Start Traefik
docker-compose pull
docker-compose up -d

# Go to https://traefik.this.test - You should have the traefik web dashboard serve over https
```

## 4. Set up your dev containers

```sh
# In your docker-compose.yml file

# Add the external network web at the end of the file
networks:
  default:
    name: docker
    external: true

# Add these labels on the container
    labels:
      - traefik.enable=true
      - traefik.http.routers.my-frontend.entrypoints=http,https
      - traefik.http.routers.my-frontend.rule=Host(`my-frontend.this.test`) # You can use any domain allowed by your TLS certificate
      - traefik.http.routers.my-frontend.tls=true
      - traefik.http.routers.my-frontend.service=my-frontend
      - traefik.http.services.my-frontend.loadbalancer.server.port=3636 # Adapt to the exposed port in the service

# Protip: For web applications, use the same origin domain for your frontend and backend to avoid cookies sharing issues.
# By example: https://this.test (frontend) and https://api.this.test (backend)
```

## Credits

[SushiFu](https://github.com/SushiFu) for their excellent repository using Brew: [traefik-local](https://github.com/SushiFu/traefik-local)
