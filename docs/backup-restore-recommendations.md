If you are using CredHub in production or a similar environment that requires resiliency, it is recommended that you create regular backups so that you can recover in the event of a component failure. CredHub itself does not store any stateful data, however, it relies on components which do and these components should be backed up. 

## Components to Back Up

* Deployment Manifest
* Encryption Keys
* Database

### Deployment Manifest

It is recommended that you maintain a copy of the most recent revision of your CredHub deployment manifest. This artifact is not strictly required, however, as the configuration information contained in the deployment manifest should be reproducible, either manually or via BOSH export using the below command. 

```
$ bosh download manifest DEPLOYMENT_NAME [FILE_PATH]
```

##### Frequency
Every new revision of the deployment manifest should be backed up. It may be appropriate to maintain this file in a revision control system to maintain these revisions automatically. 

### Backing Up the Encryption Key(s)

The process for backing up the CredHub encryption key differs based on the encryption provider enabled. The following list includes recommendations for each supported type. 

#### internal

The internal provider performs encryption and decryption operations using a symmetrical AES key. This key, which is a hexadecimal value provided to the application during deployment, should be stored in a secure place so that it can be provided in a future recovery deployment. 

#### Luna HSM

The Luna HSM is designed to not allow the removal of key material stored on the device. This security principal means a traditional data export is not possible with a Luna HSM. The two recommended options for data resiliency with a Luna HSM provider are to setup a redundant HSM configuration or to manage a 'Luna Backup HSM' device. 

Starting in v0.5.0, CredHub supports management and integration to an HA Luna HSM cluster. In this configuration, multiple (N) HSMs service requests using mirrored partitions, each containing a copy of the encryption key. This provides redundancy so that N–1 HSMs may fail without the loss availability or key material. 

An example of an HA HSM configuration can be [found here][1]. 

Additional information on backup and restore to a Luna Backup HSM can be [found here][2].

If you are using an Luna HSM from AWS, you may also refer to [their reference documentation][3] on HA and backup. 

[1]:https://github.com/pivotal-cf/credhub-release/blob/0.6.1/sample-manifests/snippet-hsm-encryption.yml#L26-L58
[2]:http://cloudhsm-safenet-docs.s3.amazonaws.com/007-011136-002_lunasa_5-1_webhelp_rev-a/Content/concepts/about_backup_local_and_remote.htm
[3]:http://docs.aws.amazon.com/cloudhsm/latest/userguide/configuring-ha.html

#### Frequency
The backup frequency of the encryption key must match the frequency with which you rotate this key so that you always have access to the latest value. 

It is also recommended that you maintain historical encryption key values equivalent to the length of time that you maintain database backups for CredHub. For example, if you maintain CredHub database backups for 1 year, you must maintain the previous 1 year of encryption keys so that you are able to access the data in the backups with the point-in-time active encryption key. 


### Database

The majority of stateful data for CredHub is stored in the configured database. This database is not deployed or managed by CredHub, so backup procedures will differ based on the selected database provider. Regardless of provider, it is recommended that you configure your database server to be highly available and redundant in addition to performing periodic backups. 

Note: After rotating your encryption key, it is recommended that you verify a backup with the latest encryption key, then destroy prior backups. This procedure will ensure that the disclosure of an prior encryption key does provide the ability to access data stored in backups.

If you are using PCF MySQL, we suggest following their [backup and restore guidelines](http://docs.pivotal.io/p-mysql/1-8/backup.html).

For more information about database backups:

[MySQL](http://dev.mysql.com/doc/refman/5.7/en/backup-and-recovery.html) <br>
[Postgres](https://www.postgresql.org/docs/9.5/static/backup.html)

##### Frequency
If you choose to only perform periodic backups, or your HA configuration has completely failed, the data loss incurred will be any actions performed in CredHub since the previous backup. 
