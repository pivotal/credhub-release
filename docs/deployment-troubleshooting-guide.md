A deployment of CredHub may fail for reasons related to its configuration or the configuration of dependent components, such as the database or encryption provider. The below guide provides a summary of how to troubleshoot a failed installation or successful installation that is not running as expected. The first section describes [deployment failures](#deployment-failures), which occur when deploying or upgrading CredHub, the second section provides information about [usability failures](#usability-failures), which occur when interacting with a successfully deployed CredHub. 

## Deployment Failures

When a deployment fails, it usually falls into one of three categories - configuration error, pre-start error or post-start error.

### Configuration Error

A configuration error occurs before the deployment is performed. These errors are caused by issues in the deployment configuration of CredHub. A sample error is shown below. 

```
Using deployment 'credhub'

Evaluating manifest:
  yaml: line 63: could not find expected ':'

Exit code 1
```

This class of errors, which always start with 'yaml' and occur before the BOSH task is created, indicate an error in parsing the manifest yaml. You should validate the structure of your manifest at the line specified to ensure it is using the proper format and indentation. 

You may also see the following error format. 

```
Task 474

18:20:35 | Preparing deployment: Preparing deployment (00:00:13)

18:20:52 | Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'credhub'. Errors are:
    - Unable to render templates for job 'credhub'. Errors are:
      - Error filling in template 'application.yml.erb' (line 22: Can't find property '["credhub.data_storage.type"]')

Started  Thu Jan 26 18:20:35 UTC 2017
Finished Thu Jan 26 18:20:52 UTC 2017
Duration 00:00:17

Task 474 error

Updating deployment:
  Expected task '474' to succeed but was state is 'error'

Exit code 1
```

This error indicates a required field is not defined in the manifest. The error above indicates the specific problem, a missing configuration value `Can't find property '["credhub.data_storage.type"]'`.

A similar error, caused by missing or invalid values, may also be thrown as shown below. 

```
Task 697

21:27:55 | Preparing deployment: Preparing deployment (00:00:14)

21:28:13 | Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'credhub'. Errors are:
    - Unable to render templates for job 'credhub'. Errors are:
      - Error filling in template 'pre-start.erb' (line 15: undefined method `[]' for nil:NilClass)

Started  Thu Jan 26 21:27:55 UTC 2017
Finished Thu Jan 26 21:28:13 UTC 2017
Duration 00:00:18

Task 697 error

Updating deployment:
  Expected task '697' to succeed but was state is 'error'

Exit code 1
```

You may narrow down the missing or invalid value for this type of error by checking the specified line number of the template indicated. For example, the above `template 'pre-start.erb' (line 15` can be found [here.](https://github.com/pivotal-cf/credhub-release/blob/master/jobs/credhub/templates/pre-start.erb#L15)

### Pre-Start Error

Pre-start errors occur when CredHub is unable to perform its [pre-start tasks][6]. This is expressed with the following deployment error. 

[6]:https://github.com/pivotal-cf/credhub-release/blob/master/jobs/credhub/templates/pre-start.erb

```
Task 789

22:34:08 | Preparing deployment: Preparing deployment (00:00:14)
22:34:26 | Preparing package compilation: Finding packages to compile (00:00:02)
22:34:28 | Updating instance dan-credhub: credhub/0261faa8-f5f4-4f6e-8ebe-3cfcba3f7190 (0) (canary) (00:00:18)
            L Error: Action Failed get_task: Task c69563a2-51e7-4b10-5c64-bb084ef85863 result: 1 of 1 pre-start scripts failed. Failed Jobs: credhub.

22:34:46 | Error: Action Failed get_task: Task c69563a2-51e7-4b10-5c64-bb084ef85863 result: 1 of 1 pre-start scripts failed. Failed Jobs: credhub.

Started  Thu Jan 26 22:34:08 UTC 2017
Finished Thu Jan 26 22:34:46 UTC 2017
Duration 00:00:38

Task 789 error

Updating deployment:
  Expected task '789' to succeed but was state is 'error'

Exit code 1
```

The first step of troubleshooting this type of error is to access the pre-start logs. These logs are stored on the deployed machine in the location `/var/vcap/sys/log/credhub/pre-start.stderr.log` and `pre-start.stdout.log`. You must ssh on to or scp the logs from the deployment machine. Task logs from bosh, e.g. `bosh task 780 --debug`, will not provide this information. 

The pre-start logs are much less verbose than the general application logs, so you will likely see the cause of the pre-start failure in the format `keytool error: java.lang.Exception: Input not an X.509 certificate`.  

### Post-Start Error

A post-start error is a generic class of errors that occur when BOSH has attempted to deploy and start CredHub, but the health check after deployment indicates that the service could not be reached. This is expressed with the following deployment error. 

```
Task 478

20:03:32 | Preparing deployment: Preparing deployment (00:00:13)
20:03:49 | Preparing package compilation: Finding packages to compile (00:00:02)
20:03:52 | Updating instance credhub: credhub/0261faa8-f5f4-4f6e-8ebe-3cfcba3f7190 (0) (canary) (00:02:34)
            L Error: Action Failed get_task: Task 5fe7ac60-4ccc-4bda-4ccb-6e88908597ef result: 1 of 1 post-start scripts failed. Failed Jobs: credhub.

20:06:27 | Error: Action Failed get_task: Task 5fe7ac60-4ccc-4bda-4ccb-6e88908597ef result: 1 of 1 post-start scripts failed. Failed Jobs: credhub.

Started  Thu Jan 26 20:03:32 UTC 2017
Finished Thu Jan 26 20:06:27 UTC 2017
Duration 00:02:55

Task 478 error

Updating deployment:
  Expected task '478' to succeed but was state is 'error'

Exit code 1
```

<a name="logs"></a>The first step of troubleshooting this type of error is to access the application logs. The primary application logs are stored on the deployed machine in the location `/var/vcap/sys/log/credhub/credhub.log`. You must ssh to or scp the logs from the deployment machine. Task logs from bosh, e.g. `bosh task 478 --debug`, will not provide this information. These logs are written according to the specified log_level value in the manifest. You may adjust this level and redeploy if you are not seeing the expected logs.

A search in the logs for 'ERROR' should locate the reason for the failure. A quick method for this is to use the command `grep -A 2 ERROR /var/vcap/sys/log/credhub/credhub.log`. Please note that monit will continually attempt to restart a failing CredHub process, so there may be multiple instances of the same error. It is best to locate the most recent error and work backward from there.

You may also validate the other log files in the `/var/vcap/sys/log/credhub` directory, however, most are expected to be empty. 

Many of these errors will provide an clear indication of the problem. For example, the below message is displayed if the application is unable to access the configured database. The message `Unable to obtain Jdbc connection from DataSource` points to the problem. 

```
2017-01-26T20:19:10.830Z [main] .... ERROR --- SpringApplication: Application startup failed
org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'flywayInitializer' defined in class path resource [org/springframework/boot/autoconfigure/flyway/FlywayAutoConfiguration$FlywayConfiguration.class]: Invocation of init method failed; nested exception is org.flywaydb.core.api.FlywayException: Unable to obtain Jdbc connection from DataSource
```

Other errors provide a generic message that may indicate any number of failures. We will attempt to document those issues in more depth below in the [Error List](#error-list) section. 

### Error List

#### [Configuration error] Can't find property '["credhub.data_storage.type"]'

This error can be resolved by adding the missing property identified in the error. You can review all of the expected manifest configurations in the [CredHub release spec](https://github.com/pivotal-cf/credhub-release/blob/master/jobs/credhub/spec).

***
#### [Configuration error] Evaluating manifest: yaml: line 54: did not find expected key` or `yaml: line 53: mapping values are not allowed in this context

This error indicates a failure to parse the yaml of the manifest. Check your manifest at the indicated line number to ensure the keys are properly named and indented. 

***
#### [Configuration error] undefined method `[]' for nil:NilClass

This error indicates that a required property has not been defined in the deployment manifest. This error will accompany the template and line number of the failure, e.g. `Error filling in template 'pre-start.erb' (line 15 ...` You may narrow down the missing value for this type of error by checking the specified line number of the template indicated. For example, the above `template 'pre-start.erb' (line 15` can be found [here.][5]

The referenced line may not point exactly to the missing value. For instance, an error may point to the line `<% if active_provider['type'] == 'hsm' %>` when it cannot properly resolve the provider of the active key. You should validate the configuration of the entire section that holds the value for these errors, e.g. the encryption section for an error involving active_provider['type'].

***
#### [Configuration error] Error: Failed to obtain valid token from UAA

This error indicates that the director was unable to obtain a token from the UAA server to authenticate with CredHub. This may be caused by an invalid client name or secret in the `director.config_server.uaa` configuration or a network issue that prevents the director from reaching UAA at the configured location. 

***
#### [Pre-start error] keytool error: java.lang.Exception: Input not an X.509 certificate

This error indicates that CredHub was unable to load either the database CA or TLS certificate from the manifest into a Java KeyStore. You may validate that the provided certificates are valid with the command `openssl x509 -text -noout -in cert.pem`. You should also validate that the indentation and formatting of the certificates is as expected in the manifest.

***
#### [Post-start error] Error creating bean with name 'flywayInitializer' defined in class path resource or Unable to obtain Jdbc connection from DataSource or ConnectionPool: Unable to create initial connections of pool

This error indicates that the application is not able to reach or interact with the configured database. 

Validate:
* The database has been created on targeted database server 
 * The named database to store CredHub data must exist on the targeted database server before you deploy CredHub. You may validate this by connecting to the database server and listing the existing databases, e.g. `mysql> show databases;` or `psql> \l`
* The username and password are valid and have appropriate access
 * The username and password must be valid and have the ability to access the specified database. You may validate this by connecting to the database with provided credentials, e.g. `mysql -h mysql.example.com -u db_user -D database_name -p` or `psql -h pgsql.example.com -U db_user -d database_name`.
* The database server is reachable from the deployment
 * The deployed machine must be able to reach the specified database server. You may validate this by ssh'ing into the deployment machine and attempting to connect to the database from that location (as above). If you are unable to connect from the deployment machine, you should validate the ingress and egress rules of the machine and targeted database server. 
* SSL configuration is appropriate and configured CA is valid
 * If you have set the property `data_storage.require_tls: true` in your manifest, you must ensure the connection is able to verify TLS connection to the server. This requires specifying the connection's CA certificate in the configuration `data_storage.tls_ca`. You may test this connection with the command line to validate that it works, e.g. `mysql -h mysql.example.com -u db_user --ssl-mode VERIFY_CA --ssl-ca ca-cert.pem -p `

***
#### [Post-start error] Caused by: com.safenetinc.luna.LunaException: Slot -1 uninitialized

This error indicates a general failure to connect to the configured Luna HSM. You should validate all of the configurations for the encryption provider to resolve this issue. 

Validate:
* The machine must be able to reach the HSM
 * The deployed machine must be able to reach the HSM. You may validate this by ssh'ing into the deployment machine and attempting to connect to the HSM from that location with the command `nc -v 10.0.0.10 1792`. It should print `Connection to 10.0.0.10 1792 port [tcp/*] succeeded!` if successful. If you are unable to connect from the deployment machine, you should validate the ingress and egress rules of the machine and targeted HSM. 
* The certificate and client certificate must be not be expired
 * You may check the certificate expiration with the OpenSSL command `openssl x509 -text -noout -in cert.pem`. Instructions on how to renew the client certificate can be [found here](configure-luna-hsm.md#renew-or-rotate-a-client-certificate).
* The certificate, client certificate and client key must be valid
 * You may check the certificates with the above command and the private key with the command `openssl rsa -text -noout -in key.pem`
* The client certificate and key must correspond to each other
 * You may check this by comparing their moduli with the command `openssl x509 -modulus -noout -in ccert.pem | sha1sum; openssl rsa -modulus -noout -in key.pem | sha1sum;`
* The client certificate and key must be registered on the HSM 
 * You can validate the registered clients on the hsm by ssh'ing into the HSM and running a few commands. Once you have connected to the HSM, the command `client list` will display all of the registered clients on the hsm. The command `client fingerprint -client client_name` will print the MD5 hash of the client certificate. You can compare this to your client certificate with the command `openssl x509 -in clientcert.pem -outform DER | md5sum`.
* The client certificate must be configured for the host and partition
 * You can validate the configuration of the client with the command `client show -client client_name`. This will list the assigned partitions and host IP address for the client.
* The partition must not be locked 
 * You can validate whether the partition is locked with the command `partition show -partition partition_name`. This will show whether the partition is locked in the field 'Partition Owner Locked Out'. If the partition is locked, you must login as HSM Admin `hsm login` then reset the partition password `partition resetPw -partition partition_name`. 
* The partition password must be valid
 * You can validate that the partition password was rejected by reviewing 'login attempt left' metric of the partition with command `partition show -partition partition_name`. If the number decrements per deployment, the provided password is being rejected. You may reset the partition password as described in the previous bullet.

***
#### [Post-start error] Error creating bean with name 'encryptionKeyService' or 'encryptionKeyCanaryMapper' or Failed to instantiate [io.pivotal.security.service.BCEncryptionService]

This failure indicates that CredHub was unable to start its data encryption service from the provided configuration. This is caused by a configuration of the keys and/or providers section of the manifest. Validate that the specified `encryption.keys` contain valid values for `dev_key` or `encryption_key_name`. Also validate that the `encryption.providers` specified include valid values.

***
#### [Post-start error] io.pivotal.security.service.EncryptionKeyCanaryMapper required a bean of type 'io.pivotal.security.service.EncryptionService' that could not be found

This failure indicates that the active encryption provider type has not be defined or is an invalid value. Check the `encryption.providers.type` value in your manifest.

#### [Post-start error] The encryption keys provided cannot decrypt any of the value(s) in the database

This failure indicates that the provided encryption key(s) provided in the deployment manifest cannot access any of the data stored in the database. You must update your encryption keys in the deployment manifest and redeploy. 

## Usability Failures

Usability failures occur after a successful deployment of CredHub. These errors are primarily related to the server's ability to reach dependent components. 

A descriptive error should be presented for usability errors when interacting via the API or CLI. If you receive an internal server error without a descriptive error, you may check the [application logs](#logs) for more information.

### Error List

#### Login timeout - "Post https://uaa.example.com:8443/oauth/token/: net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)"

This error indicates that the CLI cannot reach the configured UAA instance. The CLI contacts the UAA instance directly during a login request. To resolve this issue, validate that the configured UAA address is valid and that it is configured to be reachable from your request location. 

#### The request token signature could not be verified. Please validate that your request token was issued by the UAA server authorized by CredHub.

This error indicates that the token presented by the CLI was not signed by the UAA instance trusted by CredHub. You should validate that your deployment manifest contains the correct UAA verification key at `credhub.user_management.uaa.verification_key`.


