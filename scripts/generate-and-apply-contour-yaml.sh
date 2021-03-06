#!/bin/bash -e

TKG_LAB_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $TKG_LAB_SCRIPTS/set-env.sh

if [ ! $# -eq 1 ]; then
  echo "Must supply cluster_name as args"
  exit 1
fi

CLUSTER_NAME=$1

IAAS=$(yq e .iaas $PARAMS_YAML)

kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME

mkdir -p generated/$CLUSTER_NAME/contour/

# Create a namespace and RBAC config for the Contour service
kubectl apply -f tkg-extensions/extensions/ingress/contour/namespace-role.yaml

# Prepare Contour custom configuration
cp tkg-extensions/extensions/ingress/contour/$IAAS/contour-data-values.yaml.example generated/$CLUSTER_NAME/contour/contour-data-values.yaml

# Not necessary for azure and aws, but it doesn't hurt
yq e -i '.envoy.service.type = "LoadBalancer"' generated/$CLUSTER_NAME/contour/contour-data-values.yaml

# Setting the right Envoy tag to use the 1.3.1 image with the CVE-2021-28682, CVE-2021-28683 and CVE-2021-29258 patches.
yq e -i '.envoy.image.tag = "v1.17.3_vmware.1"' generated/$CLUSTER_NAME/contour/contour-data-values.yaml

# Add in the document seperator that yq removes
add_yaml_doc_seperator generated/$CLUSTER_NAME/contour/contour-data-values.yaml

# Create secret with custom configuration
kubectl create secret generic contour-data-values --from-file=values.yaml=generated/$CLUSTER_NAME/contour/contour-data-values.yaml -n tanzu-system-ingress -o yaml --dry-run=client | kubectl apply -f-

# Deploy Contour Extension
kubectl apply -f tkg-extensions/extensions/ingress/contour/contour-extension.yaml

# Wait until reconcile succeeds
while kubectl get app contour -n tanzu-system-ingress | grep contour | grep "Reconcile succeeded" ; [ $? -ne 0 ]; do
  echo contour extension is not yet ready
  sleep 5
done

# Contour would not spinup an http listener on the envoy service until an http ingress or httpproxy is created
# Specifically for AWS, the load balancer created for the envoy service, uses the http port on the node port
# for health check.  This causes a problems with our auth services which use a httpproxy with tls pass through
# as that does not activate the http listen and thus doesn't set AWS load balancers to active.  By deploying this
# service and httpproxy with non-tls endpoint, we activate the load balancer's health check
kubectl apply -f tkg-extensions-mods-examples/ingress/contour/warm-up-envoy.yaml
