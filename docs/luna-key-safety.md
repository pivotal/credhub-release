The Luna HSM is designed to not allow the removal of key material stored on the device. This security principal means a traditional data export for backup and restore purposes is not possible. To ensure your encryption key is not lost, which would result in the loss of access to all data encrypted by the key, you must configure your architecture to ensure the key material is redundant and be aware of some safety controls in place on the HSM. 

### Data Resiliency

The two recommended options for data resiliency with a Luna HSM provider are to setup a redundant HSM configuration or to manage a 'Luna Backup HSM' device.

Starting in v0.5.0, CredHub supports management and integration to an HA Luna HSM cluster. In this configuration, multiple (N) HSMs service requests using mirrored partitions, each containing a copy of the encryption key. This provides redundancy so that N–1 HSMs may fail without the loss availability or key material. For more information on how to configure multiple Luna HSMs in a high-availability architecture, see the [Configure Luna HSM][1] documentation.

[1]:configure-luna-hsm.md

Additional information on backup and restore to a Luna Backup HSM can be [found here.](http://cloudhsm-safenet-docs.s3.amazonaws.com/007-011136-002_lunasa_5-1_webhelp_rev-a/Content/concepts/about_backup_local_and_remote.htm)

### Safety Controls 

The Luna HSM includes security controls to prevent malicious users from attempting to gain access to administrative functions or key operations. The two primary controls to be aware of associated to the administrative user and the partition owner. 

#### Administrative User (aka Security Officer) 

A control exists for authentication as the administrative (SO) user, which will completely erase the HSM contents after 3 consecutive login failures. After a login failure, you will see an error similar to the message below. 

```
[hsm-2-2-5-9] lunash:>hsm login

Caution:  You have only TWO HSM Admin logins attempts left (including
          this one). If you fail two more consecutive login attempts
          (i.e. with no successful logins in between) the HSM will
          be ZEROIZED!!!

  Please enter the HSM Administrators' password:
  > 
```

[Per Luna documentation][3], the threshold number cannot be adjusted and this feature cannot be turned off. It should be noted that this only applies to administrative login attempts in the Luna console after a successful SSH into the HSM. This requirement will prevent a non-authenticated user from maliciously triggering this threshold, however, extra care should be exercised in handling the HSM SSH credentials with this in mind. 

[3]:https://cloudhsm-safenet-docs.s3.amazonaws.com/007-011136-002_lunasa_5-1_webhelp_rev-a/Content/administration/failed_logins.htm

#### Partition Owner

A control similar to the above also exists for the partition password, except the outcome and threshold count can be configured. The threshold can be configured from 1-10 failed attempts. The outcome of hitting the threshold of failed attempts can be configured to either delete or lock the partition. In the case of a partition lock, this must be unlocked by an administrative user. 

You can validate the outcome setting by viewing HSM policy #15 `SO can reset partition PIN`. If this value is set to 'On', the partition will lock when the threshold is hit. If set to 'Off', the partition will be deleted. As mentioned in the below description, this is a destructive setting, so if the configuration needs to be changed, the entire HSM must be erased.

```
[hsm-2-2-5-9] lunash:>hsm showP

   HSM Label:   ...
   Serial #:    ...
   Firmware:    6.20.2

   The following policies describe the current configuration of
   this HSM and may by changed by the HSM Administrator.

   Changing policies marked "destructive" will zeroize (erase
   completely) the entire HSM.

   Description                              Value        Code      Destructive
   ===========                              =====        ====      ===========
   ...
   SO can reset partition PIN               On           15        Yes
```

The example below shows what will appear if a partition is locked. To unlock the partition, you will need to login as admin with `hsm login`, then force reset the partition password with `partition resetPw -p partition-name`.

```
[hsm-2-2-5-9] lunash:>partition sh -p example

   Partition SN:                           123456789
   Partition Name:                         example
   Partition Owner Locked Out:             yes
   Partition Owner PIN To Be Changed:      no
   Partition Owner Login Attempts Left:    None - Owner is Locked Out
   Legacy Domain Has Been Set:             no
   Partition Storage Information (Bytes):  Total=108160, Used=148, Free=108012
   Partition Object Count:                 1
```

The following actions will counts against the partition owner failure threshold: 

* An incorrect partition password in a manifest will count against the lock threshold once per deployment. 
* Automatic application restarts and `monit restart` do not count additional attempts against the threshold. 
* Deploying multiple instances will count as many failures as canaries are configured.
* Attempts using a client that is not assigned to the partition, using the wrong partition serial number, wrong HSM certificate or where the client certificate/key are invalid do not count, regardless of the validity of the partition password. 
