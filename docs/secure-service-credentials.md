This guide provides instructions on how to enable [Secure Service Delivery for Cloud Foundry](https://github.com/cloudfoundry-incubator/credhub/blob/master/docs/initiatives/secure-service-credentials.md) using [cf-deployment](https://github.com/cloudfoundry/cf-deployment).

## Table of Contents

* [Pre-deploy steps](#Pre-deploy steps)
* [Deploy Cloud Foundry](#Deploy Cloud Foundry)
* [Post-deploy steps](#Post-deploy steps)

### Pre-deploy steps

1. Setup your CF infrastructure. More details are in the [cf-deployment](https://github.com/cloudfoundry/cf-deployment) repo. 
1. Create a load balancer for the CredHub cluster. It has to be a TCP load balancer to ensure no TLS termination at the load balancer. The firewall rules need to allow traffic on CredHub's default port `8844`.
1. Create DNS entry `credhub.((system_domain))` to point at the CredHub's load balancer from previous step.
1. Update cloud config on your BOSH director to include [VM Extension](http://bosh.io/docs/cloud-config.html#vm-extensions) for the load balancer. The name of the VM extension has to be `credhub-lb` as that is what the ops file references.

##### Required Manifest Changes

Required manifest modifications are in the [secure-service-credentials.yml](https://github.com/ishustava/cf-deployment/blob/develop/operations/experimental/secure-service-credentials.yml) ops file. Here is the summary the changes:
* Adds a CredHub instance group to cf deployment
* Adds a database
* Enables [Instance Identity](https://github.com/cloudfoundry/diego-release/blob/develop/docs/instance-identity.md) on Diego
* Adds CredHub's server CA to the container trust store

### Deploy Cloud Foundry

```bash
bosh -e <env> deploy \
  cf-deployment.yml \
  -d cf \
  -v system_domain=<your_system_domain> \
  -o operations/bypass-cc-bridge.yml \
  -o operations/experimental/secure-service-credentials.yml
```

### Post-deploy steps

After deploying cloud foundry with the above configuration, you need to set running environment for the CredHub API:
```bash
cf set-running-environment-variable-group '{"CREDHUB_API":"https://credhub.<your_system_domain>:8844"}'
```
