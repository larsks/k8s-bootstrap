#!/bin/sh

set -e

for policy in policy/*.hcl; do
	policy_name="${policy##*/}"
	policy_name="${policy_name%.hcl}"
	echo "configuring policy $policy_name"
	vault policy write "$policy_name" "$policy"
done

echo "configuring token role"
vault write auth/token/roles/house-secret-reader \
	allowed_policies=house-secret-reader
