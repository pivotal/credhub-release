# CA Rotation

CredHub offers support for zero-downtime rotation of certificate credentials by allowing certificates to have multiple "active" versions at the same time. 

The workflow at a high-level for transitioning to a new certificate is:

0. If not already configured, redeploy your CredHub server with the `credhub.certificates.concatenate_cas: true` option. This will combine all active versions of a CA in a certificate's `.ca` field.
1. Regenerate your CA certificate with the `transitional` flag. This creates a new version that will _not_ be used for signing yet, but can be added to your servers trusted certificate lists. Then, propagate the concatenated CAs to your software (e.g. BOSH redeploy).
1. Remove the transitional flag from the new CA certificate, and add it to the old CA certificate. This means that the new certificate will start to be used for signing, but the old one will remain as trusted.
1. Regenerate certificates that are signed by the CA, and then propagate new certificates to your software (e.g. BOSH redeploy).
1. Remove the transitional flag from the old CA certificate. Optionally, again propagate changes to your software to remove old CA (e.g. BOSH redeploy).

## Step 1: Regenerate
_For the purpose of this example, we'll be using the credential path `/example-ca` to refer to a CA stored on the CredHub server and `/example-leaf` to refer to a certificate signed by that CA. Replace this value with the path of the CA you wish to rotate._

First we'll need to get the ID of the CA certificate. Ensure you're targeting and logged-in to the proper CredHub server.

```
$ credhub curl -p "/api/v1/certificates?name=/example-ca"

{
  "certificates": [
    {
      "id": "00000000-0000-0000-0000-000000000000",
      "name": "/example-ca",
      ...
    }
  ]
}
```

Next, we use that ID to generate the new, transitional version:

```
$ credhub curl -p "/api/v1/certificates/00000000-0000-0000-0000-000000000000/regenerate" -d '{"set_as_transitional": true}' -X POST
```

You should now see that when you request the "current" versions of that CA credential, that both versions are returned:

```
$ credhub curl -p "/api/v1/data?name=/example-ca&current=true"

{
  "data": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "transitional": false,
      ...
    },
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "transitional": true,
      ...
    }
  ]
}
```

Also, if you request `/example-leaf`, you should see both versions of the CA certificate in the `ca` field:

```
$ credhub get -n /example-leaf

name: /example-leaf
value:
  ca: |
    -----BEGIN CERTIFICATE-----
    <OLD-VERSION>
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    <NEW-VERSION (TRANSITIONAL)>
    -----END CERTIFICATE-----
  ...
```

## Step 2: Moving the transitional flag
To move the transitional flag off of the new CA certificate and onto the older version, we'll need to grab the older version's ID:

```
$ credhub curl -p "/api/v1/certificates?name=/example-ca"

{
  "certificates": [
    {
      "id": "00000000-0000-0000-0000-000000000000",
      "versions": [
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "transitional": false,
          ...
        },
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "transitional": true,
          ...
        }
      ]
    }
  ]
}
```

Find the ID of the CA certificate version that currently has `transitional: false`, and then pass it to the next command:

```
$ credhub curl -p /api/v1/certificates/00000000-0000-0000-0000-000000000000/update_transitional_version -d '{"version": "11111111-1111-1111-1111-111111111111"}' -X PUT
```

You can confirm that now the two CA certificate versions have swapped:

```
$ credhub curl -p "/api/v1/data?name=/example-ca&current=true"

{
  "data": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "transitional": true,
      ...
    },
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "transitional": false,
      ...
    }
  ]
}
```

The order has also been swapped in the `ca` field of `/example-leaf`:

```
$ credhub get -n /example-leaf

name: /example-leaf
value:
  ca: |
    -----BEGIN CERTIFICATE-----
    <NEW-VERSION>
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    <OLD-VERSION (TRANSITIONAL)>
    -----END CERTIFICATE-----
  ...
```


## Step 3: Regenerate certificates

Regenerate all certificates that are signed by the new CA certificate.

## Step 4: Removing the transitional flag

After you have regenerated all your certificates, you can safely remove the transitional flag from the old one:

```
$ credhub curl -p /api/v1/certificates/00000000-0000-0000-0000-000000000000/update_transitional_version -d '{"version": null}' -X PUT
```

You can now confirm that only one CA certificate version is active:

```
$ credhub curl -p "/api/v1/data?name=/example-ca&current=true"

{
  "data": [
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "transitional": false,
      ...
    }
  ]
}
```

And only the new CA certificate version is returned in the `ca` field of `/example-leaf`:

```
$ credhub get -n /example-leaf

name: /example-leaf
value:
  ca: |
    -----BEGIN CERTIFICATE-----
    <NEW-VERSION>
    -----END CERTIFICATE-----
  ...
```
