# Create workload cluster

The example workload cluster leverages common components that were used to create the shared services cluster:

- Creating a workload cluster enabled for OIDC
- Attaching the newly created cluster to TMC
- Applying default policy on the cluster allowing platform-team admin access
- Setting up contour for ingress with a cluster certificate issuer
- Setting up fluent-bit to send logging to the centralized Elasticsearch server on shared services cluster
- Setting up Tanzu Observability for metrics
- Setting up daily Velero backups

Here we are pulling the following values from the `params.yaml` file.  See examples

```yaml
workload-cluster:
  worker-replicas: 2
  name: highgarden
  ingress-fqdn: '*.highgarden.tkg-aws-e2-lab.winterfell.live'
  gangway-fqdn: gangway.highgarden.tkg-aws-e2-lab.winterfell.live
```

Now you can execute the following script to perform all of those tasks:

```bash
./scripts/deploy-all-workload-cluster-components.sh
```

>Note: Wait until your cluster has been created and components installed. It may take 12 minutes.
>Note: Once cluster is created your kubeconfig already has the new context as the active one with the necessary credential

## Validation Step

There are lots of potential validation steps, but let's focus on the ability to login.

1. (Using Incognito Window) Login to the workload cluster at the configured `shared-services-cluster.gangway-fqdn` using `https://`
2. Click Sign In
3. Log into okta as alana user
4. Give a secret password
5. Download kubeconfig
6. Attempt to access the cluster with the new config

```bash
KUBECONFIG=~/Downloads/kubeconf.txt kubectl get pods -A
```
