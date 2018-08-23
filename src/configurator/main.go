package main

import (
	"configurator/config"
	"encoding/json"
	"fmt"
	"os"

	"errors"

	"configurator/pkcs8"
	"crypto/x509"
	"encoding/pem"
	"log"

	yaml "gopkg.in/yaml.v2"
)

func main() {

	stat, err := os.Stdin.Stat()
	if err != nil {
		panic(err)
	}

	if (stat.Mode() & os.ModeCharDevice) != 0 {
		fmt.Fprintln(os.Stderr, "Usage: <json> | configurator")
		os.Exit(1)
	}

	fmt.Fprintln(os.Stdin)
	var boshConfig config.BoshConfig

	if err := json.NewDecoder(os.Stdin).Decode(&boshConfig); err != nil {
		panic(err)
	}

	port, err := boshConfig.Port.Int64()
	if err != nil {
		panic(err)
	}

	credhubConfig := config.NewDefaultCredhubConfig()
	credhubConfig.Server.Port = port
	credhubConfig.Security.Authorization.ACLs.Enabled = boshConfig.Authorization.ACLs.Enabled

	for _, permission := range boshConfig.Authorization.Permissions {
		credhubPermission := config.Permission{
			Path:       permission.Path,
			Actors:     permission.Actors,
			Operations: permission.Operations,
		}
		credhubConfig.Security.Authorization.Permissions = append(credhubConfig.Security.Authorization.Permissions, credhubPermission)

	}

	if boshConfig.Java7TlsCiphersEnabled {
		credhubConfig.Server.SSL.Ciphers = config.Java7CipherSuites
	}

	if len(boshConfig.Authentication.MutualTLS.TrustedCAs) > 0 {
		credhubConfig.Server.SSL.ClientAuth = "want"
		credhubConfig.Server.SSL.TrustStore = config.ConfigPath + "/mtls_trust_store.jks"
		credhubConfig.Server.SSL.TrustStorePassword = "MTLS_TRUST_STORE_PASSWORD_PLACEHOLDER"
		credhubConfig.Server.SSL.TrustStoreType = "JKS"
	}

	if boshConfig.Authentication.UAA.Enabled {
		credhubConfig.Security.OAuth2.Enabled = true
		credhubConfig.AuthServer.URL = boshConfig.Authentication.UAA.Url
		credhubConfig.AuthServer.TrustStore = config.DefaultTrustStorePath
		credhubConfig.AuthServer.TrustStorePassword = config.TrustStorePasswordPlaceholder
		credhubConfig.AuthServer.InternalURL = boshConfig.Authentication.UAA.InternalUrl
	}

	if boshConfig.Bootstrap {
		credhubConfig.Encryption.KeyCreationEnabled = true
		credhubConfig.Spring.Flyway.Enabled = true
	}

	for _, provider := range boshConfig.Encryption.Providers {
		credhubProvider := config.Provider{
			ProviderName: provider.Name,
			ProviderType: provider.Type,
		}

		credhubProvider.Config = provider.ConnectionProperties

		if provider.ConnectionProperties.Partition != "" && provider.ConnectionProperties.PartitionPassword != "" {
			credhubProvider.Config.PartitionPassword = provider.ConnectionProperties.PartitionPassword
			credhubProvider.Config.Partition = provider.ConnectionProperties.Partition
		}

		for _, key := range boshConfig.Encryption.Keys {
			if key.ProviderName == provider.Name {
				credhubKey := config.Key{
					Active: key.Active,
				}

				if provider.Type == "internal" && (key.KeyProperties.EncryptionPassword == "") {
					panic(errors.New("Internal providers require encryption_password."))
				} else if provider.Type == "hsm" && (key.KeyProperties.EncryptionKeyName == "") {
					panic(errors.New("Hsm providers require encryption_key_name."))
				} else if provider.Type == "external" && key.KeyProperties.EncryptionKeyName == "" {
					panic(errors.New("External providers require encryption_key_name."))
				}

				credhubKey.EncryptionPassword = key.KeyProperties.EncryptionPassword
				credhubKey.EncryptionKeyName = key.KeyProperties.EncryptionKeyName

				credhubProvider.Keys = append(credhubProvider.Keys, credhubKey)
			}
		}

		if provider.ConnectionProperties.ClientKey != "" {
			derKey, _ := pem.Decode([]byte(provider.ConnectionProperties.ClientKey))
			if derKey == nil {
				log.Fatalf("Provider client private key must be PEM encoded for provider: %s", provider.Name)
			}
			pkcs8DERBytes := derKey.Bytes
			_, err := x509.ParsePKCS8PrivateKey(derKey.Bytes)
			if err != nil {
				key, err := x509.ParsePKCS1PrivateKey(derKey.Bytes)
				if err != nil {
					log.Fatalf("Provider client private key is not in PKCS1 or PKCS8 format: [%s, %s]", provider.Name, err)
				}
				pkcs8DERBytes, err = pkcs8.MarshalPKCS8PrivateKey(key)
				if err != nil {
					log.Fatalf("Error converting PKCS1 key to PKCS8 for provider: [%s, %s]", provider.Name, err)
				}
			}
			pkcs8Block := &pem.Block{
				Type:  "PRIVATE KEY",
				Bytes: pkcs8DERBytes,
			}
			pkcs8Key := pem.EncodeToMemory(pkcs8Block)

			credhubProvider.Config.ClientKey = string(pkcs8Key)
		}
		credhubConfig.Encryption.Providers = append(credhubConfig.Encryption.Providers, credhubProvider)

	}

	switch boshConfig.DataStorage.Type {
	case "in-memory":
		credhubConfig.Spring.Flyway.Locations = config.H2MigrationsPath
	case "mysql":
		credhubConfig.Spring.Flyway.Locations = config.MysqlMigrationsPath
		connectionString := config.MysqlConnectionString
		if boshConfig.DataStorage.RequireTLS {
			connectionString = config.MysqlTlsConnectionString
			if !boshConfig.DataStorage.HostnameVerification.Enabled {
				connectionString += config.MysqlTlsDisableHostnameVerification
			}
		}
		credhubConfig.Spring.Datasource.URL = fmt.Sprintf(connectionString,
			boshConfig.DataStorage.Host, boshConfig.DataStorage.Port, boshConfig.DataStorage.Database)
		credhubConfig.Spring.Datasource.Username = boshConfig.DataStorage.Username
		credhubConfig.Spring.Datasource.Password = boshConfig.DataStorage.Password
	case "postgres":
		credhubConfig.Spring.Flyway.Locations = config.PostgresMigrationsPath
		connectionString := config.PostgresConnectionString
		if boshConfig.DataStorage.RequireTLS {
			connectionString = config.PostgresTlsConnectionString
		}
		credhubConfig.Spring.Datasource.URL = fmt.Sprintf(connectionString,
			boshConfig.DataStorage.Host, boshConfig.DataStorage.Port, boshConfig.DataStorage.Database)
		credhubConfig.Spring.Datasource.Username = boshConfig.DataStorage.Username
		credhubConfig.Spring.Datasource.Password = boshConfig.DataStorage.Password
	default:
		fmt.Fprintln(os.Stderr, `credhub.data_storage.type must be set to "mysql", "postgres", or "in-memory".`)
		os.Exit(1)
	}

	byteArray, err := yaml.Marshal(credhubConfig)
	if err != nil {
		panic(err)
	}

	fmt.Printf("%s", byteArray)
	os.Exit(0)
}
