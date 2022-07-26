#!/usr/bin/env bash

# Assumes that the image is already built

TEST_CERT='Yes'

DOMAINS='yourhost.example.com'
CLOUDFLARE_EMAIL='you@example.com'
CLOUDFLARE_API_TOKEN='<token>'

DIE_DELAY_SECS=600

mkdir -p certs

docker run \
  --volume "$(pwd)/certs:/mnt:Z" \
  --interactive \
  --tty \
  --name 'cflegetter' \
  --env DOMAINS="${DOMAINS}" \
  --env CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL}" \
  --env CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}" \
  --env DIE_DELAY_SECS="${DIE_DELAY_SECS}" \
  --env TEST_CERT="${TEST_CERT}" \
  docker.io/freedomben/cfle-getter:latest


echo "CFLE getter has exited with staus ${?}.  If successful, the certs should be in the 'certs' directory"
