#!/usr/bin/env bash

# Example Env vars:
#CLOUDFLARE_EMAIL='ben@example.com'
#CLOUDFLARE_API_TOKEN='awekjltaSAGKLHG'
#DOMAINS='example.com,*.example.com'

#DIE_DELAY_SECS='28800' # seconds to sleep before exiting on failure. 28800 is 8 hours

#set -o nounset  # Uncomment for debugging

# Use `help declare` to get more info about declare options

die ()
{
  local exit_code="${1:-99}"
  local msg="${2}"
  if ! [[ $exit_code =~ ^-?[0-9]+$ ]]; then
    echo "Warning: exit code provided to die() was not an integer.  Defaulting to 98"
    exit_code=98
    if [ -z "${2}" ]; then
      echo "Using arg 1 as message since one was not provided"
      msg="${1}"
    fi
  fi
  echo "[DIE] Exit code '${exit_code}' - $(date): ${msg}"

  if [ -n "${DIE_DELAY_SECS}" ]; then
    echo "DIE_DELAY_SECS is set.  Delaying exit by sleeping for ${DIE_DELAY_SECS} seconds"
    sleep "${DIE_DELAY_SECS}"
  else
    echo "DIE_DELAY_SECS is not set.  To delay exit, set DIE_DELAY_SECS"
  fi
  exit ${exit_code}
}

log ()
{
  echo -e "[LOG] - $(date): ${1}"
}

test_cert ()
{
  if [ -z "${TEST_CERT}" ] || [[ $TEST_CERT =~ [Nn] ]]; then
    echo ""
  else
    echo "--test-cert"
  fi
}

if [ -z "$CLOUDFLARE_EMAIL" ]; then
  die '3' 'CFLE cannot renew Lets Encypt certificate because the CLOUDFLARE_EMAIL env var is empty.  Set appropriately and try again'
elif [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  die '4' 'CFLE cannot renew Lets Encypt certificate because the CLOUDFLARE_API_TOKEN env var is empty.  Set appropriately and try again'
elif [ -z "$DOMAINS" ]; then
  die '5' 'CFLE cannot renew Lets Encypt certificate because the DOMAINS env var is empty.  Set appropriately and try again'
fi

# Basic algo:
#  - Setup cloudflare access
#  - Renew certificate with certbot

set -e

log 'Configuring Cloudflare API access'
cd /root/
mkdir -p /root/.secrets/
touch /root/.secrets/cloudflare.ini
cat << EOF > /root/.secrets/cloudflare.ini
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOF

chmod 0700 /root/.secrets/
chmod 0400 /root/.secrets/cloudflare.ini

if [ -n "$(test_cert)" ]; then
  log "We ARE in test mode because env var TEST_CERT is set to something besides empty or 'No' ('${TEST_CERT}').  this certificate will come from the Let's Encrypt sandbox server, meaning it will not be valid from a user's perspective"
else
  log "We are NOT in test mode because env var TEST_CERT is not set.  This certificate will come from the real Let's Encrypt server and is subject to rate limiting"
fi

log 'Beginning Lets Encrypt DNS-01 challenge'

set +e

certbot certonly $(test_cert) \
  --non-interactive \
  --force-renewal \
  --agree-tos \
  --email "${CLOUDFLARE_EMAIL}" \
  --eff-email \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  --domains "${DOMAINS}" \
  --preferred-challenges dns-01

if [ "$?" != "0" ]; then
  status_code="$?"
  log 'certbot failed to renew certificates'
  die '7' "$(certbot_failure_message "$status_code")"
fi

log 'Lets Encrypt DNS-01 challenge finished.  Bundling into a .tar.gz'

set -e

timestamp="$(date +%Y-%m-%d-%H-%M-%S)"
outputdir="/mnt/${timestamp}-tls-certs"
mkdir -p "${outputdir}"
cp /etc/letsencrypt/live/*/* "${outputdir}/"
tar czvf "${outputdir}.tar.gz" "${outputdir}"
cd "${outputdir}"

set +e

log "Certificate for ${DOMAINS} updated successfully.  Cert placed in ${outputdir}"

log "openssl check of the full chain cert:"
openssl x509 -noout -text -in fullchain.pem

log "openssl check of the cert only:"
openssl x509 -noout -text -in cert.pem
