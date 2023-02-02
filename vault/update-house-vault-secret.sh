#!/bin/bash

tmpfile="$(mktemp secretXXXXXX.json)"
trap 'rm -f $tmpfile' EXIT

if ! kubectl -n config get secret house-vault -o json > "$tmpfile" 2>/dev/null; then
	echo "create house-vault secret"
	kubectl -n config create secret generic house-vault -o json > "$tmpfile"
fi

old_accessor="$(jq -r '.metadata.annotations."vault-accessor"' "$tmpfile")"

if [[ -n "$old_accessor" ]] && vault token lookup -accessor "$old_accessor" > /dev/null 2>&1; then
	echo "existing house-vault token is good"
	exit
fi

echo "create new vault token"
vault token create -role house-secret-reader -format json > "$tmpfile"

token="$(jq -r '.auth.client_token' "$tmpfile")"
accessor="$(jq -r '.auth.accessor' "$tmpfile")"
if [ -z "$token" ]; then
	echo "ERROR: failed to get secret" >&2
	exit 1
fi

kubectl -n config patch secret house-vault --patch-file /dev/stdin <<END_PATCH
{
  "metadata": {
    "annotations": {
      "vault-accessor": "$accessor"
    }
  },
  "data": {
    "token": "$(base64 -w0 <<<"$token")"
  }
}
END_PATCH
