#!/bin/bash

if [ "${DEBUG}" = 1 ]; then
    set -x
fi
# Get all secrets related to the tenant, excluding the helm release and config secrets
secrets=$(kubectl get secrets -n $ETCD_NAMESPACE -o json | jq -r '.items[].metadata.name' | grep -v "helm.release" | grep -vi "config" | grep $ETCD_NAME)

# Loop through each secret
for secret in $secrets
do
  echo -e "\nSecret: $secret"
  echo "Data:"
  
  # Get the data from the secret
  data=$(kubectl get secret $secret -n $ETCD_NAMESPACE -o json | jq -r '.data[]')

    # Decode the value from base64 encoding and print certificate properties
    decoded_value=$(echo $data | base64 --decode | openssl x509 -noout -dates -fingerprint -sha256 -inform pem)

    echo "$key${decoded_value}"
  done
