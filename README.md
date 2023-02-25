# Traefik Local for Nix (nix-darwin/NixOS)

Set up a local Traefik web proxy with DNS resolution on \*.test domains.

Also sets up a local trusted Root CA and create a TLS certificate for using HTTPS in local (shout out to [mkcert](https://github.com/FiloSottile/mkcert)).

## 0. Prerequisites

- [Docker for Mac](https://docs.docker.com/docker-for-mac/install/) or [enabled on NixOS](https://nixos.wiki/wiki/Docker)
- [Nix-Darwin](https://github.com/LnL7/nix-darwin) or [NixOS](https://nixos.org)

## 1. Setup resolvers

Enable the `dnsmasq` service, pointing to your localhost.

nix-darwin:

```nix
{
  services.dnsmasq = {
    enable = true;
    addresses."test" = "127.0.0.1";
    bind = "127.0.0.1";
  };
}
```

NixOS:

```nix
{
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      address=/test/127.0.0.1
    '';
  };
}
```

To verify this worked, `cat /etc/resolver/test` should return (macOS specific)

```
port 53
nameserver 127.0.0.1
```

And `ping this.test` should get a response from `127.0.0.1` (universal).

## 2. Set up a local Root CA, and prepare certificates

Clone this repository

```sh
git clone https://github.com/nekowinston/traefik-local-nix.git
cd traefik-local/
```

We're using `nix-shell` here, since these are not runtime dependencies.

```sh
nix-shell -p mkcert nssTools
```

### Set up the local Root CA

```sh
mkcert -install
```

Local Root CA files are located under `~/Library/Application\ Support/mkcert`.
Look at the [mkcert docs](https://github.com/FiloSottile/mkcert#mobile-devices), if you need instructions to install them on another device.

### Create a local TLS certificate

You could add any domain you need ending by .lan or .test
\*.this.test will create a wildcard certificate so any subdomain in the form like.this.test will also work.
Unfortunately you cannot create \*.test wildcard certificate - your browser will not allow it.

```sh
mkcert -cert-file certs/local.crt -key-file certs/local.key "this.test" "*.this.test"
```

## 3. Set up a Traefik container with HTTPS

Create an external network docker, all future containers which need to be exposed by domain name should use this network.

```sh
docker network create docker
```

Start Traefik

```sh
docker-compose up -d
```

Go to https://traefik.this.test - You should have the Traefik web dashboard serve via HTTPS

## 4. Set up your dev containers

In the `docker-compose.yml` file in your project:

Add the external network web at the end of the file

```yaml
networks:
  default:
    name: docker
    external: true
```

Add these labels on the container(s)

```yaml
services:
  my-frontend:
    labels:
      - traefik.enable=true
      - traefik.http.routers.my-frontend.entrypoints=http,https
      - traefik.http.routers.my-frontend.rule=Host(`my-frontend.this.test`) # You can use any domain allowed by your TLS certificate
      - traefik.http.routers.my-frontend.tls=true
      - traefik.http.routers.my-frontend.service=my-frontend
      - traefik.http.services.my-frontend.loadbalancer.server.port=3636 # Adapt to the exposed port in the service
```

> **Note**\
> For web applications, use the same origin domain for your frontend and backend to avoid cookies sharing issues.
> Example: https://this.test (frontend) and https://api.this.test (backend)

## Credits

[SushiFu](https://github.com/SushiFu) for their excellent repository using Brew: [traefik-local](https://github.com/SushiFu/traefik-local)
