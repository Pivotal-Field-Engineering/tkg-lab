#!/bin/bash -e

TKG_LAB_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $TKG_LAB_SCRIPTS/../scripts/set-env.sh

if [ ! $# -eq 1 ]; then
  echo "Must supply cluster_name as args"
  exit 1
fi

CLUSTER_NAME=$1
kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME

echo "Beginning Harbor install..."

HARBOR_CN=$(yq r $PARAMS_YAML harbor.harbor-cn)
NOTARY_CN=$(yq r $PARAMS_YAML harbor.notary-cn)

mkdir -p generated/$CLUSTER_NAME/harbor

# 01-namespace.yaml
yq read harbor/01-namespace.yaml > generated/$CLUSTER_NAME/harbor/01-namespace.yaml

# 02-certs.yaml
yq read harbor/02-certs.yaml > generated/$CLUSTER_NAME/harbor/02-certs.yaml
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.commonName" $HARBOR_CN
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.dnsNames[0]" $HARBOR_CN
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.dnsNames[1]" $NOTARY_CN

# harbor-values.yaml
yq read harbor/harbor-values.yaml > generated/$CLUSTER_NAME/harbor/harbor-values.yaml
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "expose.ingress.hosts.core" $HARBOR_CN
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "expose.ingress.hosts.notary" $NOTARY_CN  
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "externalURL" https://$HARBOR_CN

helm repo add harbor https://helm.goharbor.io
# generate the helm manifest and make sure the core pod trusts let's encrypt
helm template harbor harbor/harbor -f generated/$CLUSTER_NAME/harbor/harbor-values.yaml --namespace harbor | 
  ytt -f - -f overlay/trust-certificate --ignore-unknown-comments \
    --data-value certificate="$(cat keys/letsencrypt-ca.pem)" \
    --data-value ca=letsencrypt > generated/$CLUSTER_NAME/harbor/helm-manifest.yaml

kapp deploy -a harbor \
  -n tanzu-kapp \
  --into-ns harbor \
  -f generated/$CLUSTER_NAME/harbor/01-namespace.yaml \
  -f generated/$CLUSTER_NAME/harbor/02-certs.yaml \
  -f generated/$CLUSTER_NAME/harbor/helm-manifest.yaml \
  -y 

echo "Okta OIDC Configurtion Values..."
echo "Auth Mode: OIDC"
echo "OIDC Provider Name: Okta"
echo "OIDC Endpoint: https://$(yq r $PARAMS_YAML okta.auth-server-fqdn)/oauth2/default"
echo "OIDC Client ID: $(yq r $PARAMS_YAML okta.harbor-app-client-id)"
echo "OIDC Client Secret: $(yq r $PARAMS_YAML okta.harbor-app-client-secret)"
echo "Group Claim Name: groups"
echo "OIDC Scope: openid,profile,email,groups,offline_access"
echo "Verify Certificate: checked"
