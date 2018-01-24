# CA Rotation

CredHub offers support for zero-downtime rotation of certificate credentials by allowing certificates to have multiple "active" versions at the same time. 

The workflow at a high-level for transitioning to a new certificate is:

1. Regenerate your CA certificate with the `transitional` flag. This creates a new version that will _not_ be used for signing yet, but can be added to your servers trusted certificate lists.
1. Remove the transitional flag from the new certificate, and add it to the old certificate. This means that the new certificate will start to be used for signing, but the old one will remain as trusted.
1. Remove the transitional flag from the old certificate. Now that all your clients should have certificates signed by the new CA's certificate, the old one can be removed from your servers trusted lists.

## Step 1: Regenerate
First we'll need to get the ID of the certificate. Assuming you're logged in with the CredHub CLI, this curl -k command will get you the ID:

```
curl -k -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" $(credhub api)/api/v1/certificates?name=$NAME
```

Next, we use that ID to generate the new, transitional version:

```
curl -k -XPOST -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" -d '{"set_as_transitional": true}' $(credhub api)/api/v1/certificates/$ID/regenerate
```

You should now see that when you request the "current" versions of that credential, that both certificates are returned:

```
curl -k -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" $(credhub api)/api/v1/data?name=$NAME\&current=true
```

## Step 2: Moving the transitional flag
To move the transitional flag off of the new certificate and onto the older version, we'll need to grab the older versions ID:

```
curl -k -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" $(credhub api)/api/v1/data?name=$NAME\&current=true
```

Find the ID of the certificate that currently has `transitional: false`, and then pass it to the next command:

```
curl -k -XPUT -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" -d "{\"version\": \"$NON_TRANSITIONAL_ID\"}" $(credhub api)/api/v1/certificates/$ID/update_transitional_version
```

You can confirm that now the two certificates have swapped:

```
curl -k -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" $(credhub api)/api/v1/data?name=$NAME\&current=true
```

## Step 3: Removing the transitional flag

After you have regenerated all your client certificates to be signed by the new cert, you can safely remove the transitional flag from the old one:

```
curl -k -XPUT -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" -d '{"version": null}' $(credhub api)/api/v1/certificates/$ID/update_transitional_version
```

You can now confirm that only one certificate is active:

```
curl -k -H "Content-Type: application/json" -H "Authorization: $(credhub --token)" $(credhub api)/api/v1/data?name=$NAME\&current=true
```
