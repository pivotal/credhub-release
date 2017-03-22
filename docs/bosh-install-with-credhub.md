The following guide provides details on how to deploy a BOSH Director with CredHub so that you may use credential variables in your deployments manifests. Once configured, any variable in a BOSH deployment manifest with the syntax ((variable)) will cause the Director to retrieve the variable value at deploy-time from CredHub.

If you use [bosh-deployment][1] to deploy your director, including the ops file `credhub.yml` will enable CredHub on the director. 
[1]:https://github.com/cloudfoundry/bosh-deployment

---
## <a id="setup"></a> Setup Before Deployment

1. Setup a BOSH Director

  The following configuration steps assume that you have an existing BOSH Director. If you do not have a running director, you may reference [this BOSH initialization guide][2] for more details. 
  [2]:https://bosh.io/docs/init.html

1. Configure UAA on your Director 

  UAA is used by CredHub for user and client authentication. A UAA server must be configured on the director to enable CredHub. You may read more on how to provision UAA on the Director [in the following guide][3].
  [3]:https://bosh.io/docs/director-users-uaa.html 

1. Generate TLS keys for the API

  CredHub requires traffic to the API to go over HTTPS. You may use a certificate issued by a known CA or generate a self-signed certificate. 

  Please note, CredHub validates the certificate for connections, so the common name and/or alternative names on the certificate must match the address used to access the CredHub API. For example, if the director uses `director.config_server.url = https://127.0.0.1:8844/api/`, the certificate must include '127.0.0.1' as an alternative name. 

  Generating a self-signed certificate with OpenSSL: `openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes`

1. [Optional] Configure a Luna SafeNet HSM

  In the recommended production configuration, cryptographic operations are performed for CredHub via an external Luna SafeNet hardware security module (HSM). The HSM must be configured to allow access from the deployed CredHub instance and the operator must have all of the required credentials from the HSM. For more information on the required HSM values and how to configure an HSM, see the [configuring a Luna HSM][4] document.
  [4]:https://github.com/pivotal-cf/credhub-release/blob/master/docs/configure-luna-hsm.md

1. [Optional] Configure an external database

  If you chose to store CredHub data in an external database, as recommended, you must create a database and user on your database server before deployment. You may use the internal Director database to store CredHub data, however care must be taken to avoid data loss during updates to or provisioning of the Director VM.

---
## <a id="configure"></a> Configuring the Director

1. Update the deployment manifest to include the CredHub release:

  You may obtain the latest CredHub release at the [following location][5].
  [5]:https://github.com/pivotal-cf/credhub-release/releases

    ```yaml
    releases:
    - name: bosh
      url: https://bosh.io/d/github.com/cloudfoundry/bosh?v=261.2
      version: 261.2
      sha1: d4635b4b82b0dc5fd083b83eb7e7405832f6654b
    # ...
    - name: credhub # <---
      url: https://github.com/pivotal-cf/credhub-release/releases/download/0.5.1/credhub-0.5.1.tgz
      version: 0.5.1
      sha1: fcfa37835c813b175defe01d8fae7d57e7ef669c
    ```

1. Co-locate CredHub next to the Director:

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
      log_level: info
      authentication:
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
        password: example-password
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
        keys: 
        - provider_name: corp-hsm
          encryption_key_name: key-name
        providers:
        - name: corp-hsm
          type: hsm
          partition: partition-name
          partition_password: partition-password
          client_certificate: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
          client_key: |
            -----BEGIN RSA PRIVATE KEY-----
            ...
            -----END RSA PRIVATE KEY-----
          servers: 
          - host: hsm.example.com
            port: 1792
            partition_serial_number: 123456
            certificate: |
              -----BEGIN CERTIFICATE-----
              ...
              -----END CERTIFICATE-----
    ```

    Alternatively, you may select to use internal software encryption for development testing with the following configuration. Note: This configuration only supports a 32 character hex key (128 bit).

    ```yml
    ...
      encryption:
        providers: 
        - name: dev
          type: internal
        keys: 
        - provider_name: dev
          dev_key: D673ACD01DA091B08144FBC8C0B5F524
    ...
    ```

    For a list of the full CredHub properties and default values, visit [the job spec properties][6] page.
  [6]:https://github.com/pivotal-cf/credhub-release/blob/master/jobs/credhub/spec

1. Add CredHub CLI and Director/CredHub UAA clients: 

    ```yaml
    properties:
      uaa:
        clients:
          credhub_cli:
            override: true
            authorized-grant-types: password,refresh_token
            scope: credhub.read,credhub.write 
            authorities: uaa.none
            access-token-validity: 120 
            refresh-token-validity: 1800
            secret: "" # <--- CLI expects this secret to be empty
          director_to_credhub:
            override: true
            authorized-grant-types: client_credentials
            scope: uaa.none
            authorities: credhub.read,credhub.write
            access-token-validity: 43200
            secret: example-secret # <--- Replace with custom client secret
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
          url: "https://127.0.0.1:8844/api/"
          
          ca_cert: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
          uaa:
            url: "https://127.0.0.1:8443"
            client_id: director_to_credhub
            client_secret: example-secret
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

  To authenticate with CredHub to manage credentials, you must have a UAA user account with the scopes credhub.read, credhub.write. You may create users manually in UAA, as [described here][7], or you may configure UAA with an external LDAP provider.
  [7]:https://docs.pivotal.io/pivotalcf/1-9/adminguide/uaa-user-management.html

  A sample process for creating a user in UAA is below:

  ```
  user$ uaac token client get admin -s example-password
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

1. Install CredHub CLI:

  CredHub CLI offers a simple interface to manage credentials and CAs. You can download the [latest release here.][8]
  [8]:https://github.com/cloudfoundry-incubator/credhub-cli/releases
  
1. Place or generate some credentials in CredHub using the CLI:

  ```
  credhub set --type ssh --name /static/ssh_key --public ~/ssh.pub --private ~/ssh.key
  credhub generate --type ssh --name /static/ssh_key
  ```

1. Update BOSH deployment manifests:

  Now that you have a Director that integrates with CredHub, you can update your deployment manifests to leverage this feature. An example is shown below of a deployment manifest using two credentials - one stored and one generated by CredHub. Credentials that you wish to be generated automatically should be defined in the `variables` section with their desired generation parameters. More information on automatic generation can be [found here][9].
  [9]:https://github.com/cloudfoundry-incubator/credhub/blob/master/docs/credential-types.md#enabling-credhub-automatic-generation-in-releases

  ```yaml 
  name: Sample-Manifest
  
  releases:
  - name: shell
    url: https://bosh.io/d/github.com/cloudfoundry-community/shell-boshrelease?v=3.2.0
    sha1: 893b10af531a7519da99bb8656cc07b8277d1692
  
  #...

  variables: 
  - name: generated/ssh_key
    type: ssh
  
  jobs:
    - name: shell
      instances: 1
      persistent_disk: 0
      resource_pool: vms
      networks:
        - name: private
          static_ips: 10.0.0.100
          default: [dns, gateway]
      templates:
        - name: shell
          release: shell
          properties:
            shell:
              users:
                - name: shell
                  ssh_keys:
                    - ((/static/ssh_key))
                    - ((generated/ssh_key))
  ```
