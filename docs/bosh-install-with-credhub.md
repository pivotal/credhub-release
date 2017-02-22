The following guide provides details on how to deploy a BOSH Director with CredHub so that you may use credential variables in your deployments manifests. Once configured, any variable in a BOSH deployment manifest with the syntax ((variable)) will cause the Director to retrieve the variable value at deploy-time from CredHub.

_WARNING: At this time, data cannot be migrated between encryption providers. You may rotate the encryption key, however, you may not migrate providers, e.g. dev_internal to HSM._

---
## <a id="setup"></a> Setup Before Deployment

1. Setup a BOSH Director

  The following configuration steps assume that you have an existing BOSH Director. If you do not have a running director, you may reference [this BOSH initialization guide][1] for more details. 
[1]:https://bosh.io/docs/init.html

1. Configure UAA on your Director 

  UAA is used by CredHub for user and client authentication. A UAA server must be configured on the director to enable CredHub. You may read more on how to provision UAA on the Director [in the following guide][2]
[2]:https://bosh.io/docs/director-users-uaa.html 

1. Generate TLS keys for the API

  CredHub requires traffic to the API to go over HTTPS. You may use a certificate issued by a known CA or generate a self-signed certificate. 

  Please note, CredHub validates the certificate for connections, so the common name and/or alternative names on the certificate must match the address used to access the CredHub API. For example, if the director uses `director.config_server.url = https://localhost:8844/api/`, the certificate must include 'localhost' as the common name or an alternative name. 

  Generating a self-signed certificate with OpenSSL: `openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes`

1. [Optional] Configure a Luna SafeNet HSM

  In the recommended production configuration, cryptographic operations are performed for CredHub via an external Luna SafeNet hardware security module (HSM). The HSM must be configured with a partition that contains an associated client certificate and key that can access the partition. The partition and client details are required in the deployment manifest to deploy CredHub.

1. [Optional] Configure an external database

  If you chose to store CredHub data in an external database, as recommended, you must create a database and user on your database server before deployment. You may use the internal Director database to store CredHub data, however care must be taken to avoid data loss during updates to or provisioning of the Director VM.

---
## <a id="configure"></a> Configuring the Director

1. Update the deployment manifest to include the CredHub release:

  You may obtain the latest CredHub release at the [following location][6].
[6]:https://github.com/pivotal-cf/cm-release/releases

    ```yaml
    releases:
    - name: bosh
      url: https://bosh.io/d/github.com/cloudfoundry/bosh?v=209
      sha1: a96833b6c68abda5aaa5d05ebdd0a5d394e6c15f
    # ...
    - name: credhub # <---
      url: file:///Users/Example/Releases/credhub.dev.1472688603.tgz
    ```
The version of BOSH which you include must support the Configuration Server.

1. Collocate CredHub next to the Director:

    ```yaml
    jobs:
    - name: bosh
      instances: 1
      templates:
      - {name: nats, release: bosh}
      - {name: redis, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: uaa, release: uaa-release}
      - {name: credhub, release: credhub} # <---
      resource_pool: default
      # ...
    ```

1. Add `credhub` properties to the deployment manifest:

    ```yaml
    credhub:
      port: 8844
      log_level: debug
      user_management:
        uaa:
          url: "https://uaa.example.com:8443"
          verification_key: |
            -----BEGIN PUBLIC KEY-----
            ...
            -----END PUBLIC KEY-----
      data_storage:
        type: mysql
        host: mysql.example.com
        port: 3306
        database: credhub
        username: user
        password: user-password
        require_tls: true
        tls_ca: |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
      tls:
        certificate: |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
        private_key: |
          -----BEGIN RSA PRIVATE KEY-----
          ...
          -----END RSA PRIVATE KEY-----
      encryption: 
        provider: hsm
        hsm:
          host: hsm.example.com
          port: 1792
          certificate: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
          partition: partition-name
          partition_password: partition-password
          encryption_key_name: key-name
          client_certificate: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
          client_key: |
            -----BEGIN RSA PRIVATE KEY-----
            ...
            -----END RSA PRIVATE KEY-----
    ```

    Alternatively, you may select to use internal software encryption for development testing with the following configuration. Note: This configuration only supports a 32 character hex key (128 bit).

    ```yml
    ...
      encryption: 
        provider: dev_internal
        dev_key: D673ACD01DA091B08144FBC8C0B5F524
    ...
    ```

    For a list of the full CredHub properties and default values, visit [the job spec properties][3] page.

[3]:https://github.com/pivotal-cf/credhub-release/blob/master/jobs/credhub/spec

1. Add CredHub CLI and Director/CredHub UAA clients: 

    ```yaml
    properties:
      uaa:
        clients:
          credhub:
            override: true
            authorized-grant-types: password,refresh_token
            scope: credhub.read,credhub.write 
            authorities: uaa.none
            access-token-validity: 120 
            refresh-token-validity: 86400
            secret: "" # <--- CLI expects this secret to be empty
          director_credhub:
            override: true
            authorized-grant-types: client_credentials
            scope: uaa.none
            authorities: credhub.read,credhub.write
            access-token-validity: 43200
            secret: client-secret # <--- Replace with custom client secret
    ```

1. Configure the Director to utilize CredHub for manifest variables:

    ```yaml
    properties:
      director:
        address: bosh.example.com
        name: director-name
        config_server:
          enabled: true
          
          # URL must contain /api/ path with trailing slash
          url: "https://localhost:8844/api/"
          
          ca_cert: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
          uaa:
            url: "https://localhost:8443"
            client_id: director_credhub
            client_secret: client-secret
            ca_cert: |
              -----BEGIN CERTIFICATE-----
              ...
              -----END CERTIFICATE-----
    ```

1. **Optional:** Configure the Director Postgres server to have an additional database called `credhub`:

  If you are using the internal Director database, you must provision an additional database for the credhub data. If you are using an external database, you must create the database on your database server before deploying.

    ```yaml
    properties:
      postgres: &db
        host: 127.0.0.1
        port: 5432
        user: postgres
        password: postgres-password
        database: bosh
        additional_databases: [credhub] # <---
        adapter: postgres
    ```

1. **Optional:** Seed initial CredHub users to UAA:

    ```yaml
    properties:
      uaa:
        scim:
          users:
          - name: credhub-user
            password: user-password
            groups:
            # Users must have both credhub.read and credhub.write access
            - credhub.read             # <---
            - credhub.write            # <---
          - name: credhub-user2
            password: user-password
            groups:
            - credhub.read
            - credhub.write
    ```

1. Deploy!

---
## <a id="after"></a> Updates After Deployment

1. Create CredHub users in UAA:

  To authenticate with CredHub to manage credentials, you must have a UAA user account with the scopes `credhub.read, credhub.write`. You may create users manually in UAA, [as described here][4], or you may configure UAA with an external LDAP provider.

  A sample process for creating a user in UAA is below:

```
user$ uaac token client get admin -s password
  Successfully fetched token via client credentials grant.
  Target: https://uaa.example.com:8443
  Context: admin, from client admin

user$ uaac user add username --emails email@example.com
  Password:  ********
  Verify password:  ********
  user account successfully added

user$ uaac member add credhub.read username
  success

user$ uaac member add credhub.write username
  success
```

[4]:https://docs.pivotal.io/pivotalcf/1-7/adminguide/uaa-user-management.html

2. Install CredHub CLI:

  CredHub CLI offers a simple interface to manage credentials and CAs. You can download the [latest release here.][5]

  [5]: https://github.com/pivotal-cf/credhub-cli/releases
  
3. Place the desired credentials in your CredHub with cli:

```
credhub set -t value -n shell/pivotal/ssh_key -v "ssh-rsa AAAAB...aurUe9G7 user@host"
```

4. Update BOSH deployment manifests:

  Now that you have a Director that integrates with CredHub, you can update your deployment manifests to leverage this feature. An example is shown below of a deployment manifest using credentials stored in CredHub. 

```yaml 
name: Sample-Manifest
director_uuid: c6483da7-8248-4193-9acf-d2548b5e551f

releases:
- name: shell
  url: https://bosh.io/d/github.com/cloudfoundry-community/shell-boshrelease?v=3.2.0
  sha1: 893b10af531a7519da99bb8656cc07b8277d1692

#...

jobs:
  - name: shell
    templates:
      - { release: shell, name: shell }
    instances: 1
    persistent_disk: 0
    resource_pool: vms
    networks:
      - name: private
        static_ips: 10.0.0.100
        default: [dns, gateway]
    properties:
      shell:
        users:
          - name: pivotal
            ssh_keys:
              - ((shell/pivotal/ssh_key))
```
