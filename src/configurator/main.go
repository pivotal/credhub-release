package main

import (
	"configurator/config"
	"encoding/json"
	"fmt"
	"os"
	//"io/ioutil"

	"gopkg.in/yaml.v2"
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
		credhubConfig.Flyway.Enabled = true
	}

	for _, key := range boshConfig.Encryption.Keys {
		var providerType string

		for _, provider := range boshConfig.Encryption.Providers {
			if provider.Name == key.ProviderName {
				providerType = provider.Type

				if provider.Type == "hsm" {
					if provider.ConnectionProperties.Partition != "" && provider.ConnectionProperties.PartitionPassword != "" {
						credhubConfig.Hsm.Partition = provider.ConnectionProperties.Partition
						credhubConfig.Hsm.PartitionPassword = provider.ConnectionProperties.PartitionPassword
					} else {
						credhubConfig.Hsm.Partition = provider.Partition
						credhubConfig.Hsm.PartitionPassword = provider.PartitionPassword
					}
				}
				break
			}

		}

		var encryptionKeyName string
		var encryptionKeyPassword string

		if key.KeyProperties.EncryptionKeyName != "" {
			encryptionKeyName = key.KeyProperties.EncryptionKeyName
		} else if key.EncryptionKeyName != "" {
			encryptionKeyName = key.EncryptionKeyName
		}
		if key.KeyProperties.EncryptionPassword != "" {
			encryptionKeyPassword = key.KeyProperties.EncryptionPassword
 		}  else if key.EncryptionPassword != "" {
			encryptionKeyPassword = key.EncryptionPassword
		}

		configKey := config.Key{
			ProviderType:       providerType,
			EncryptionKeyName:  encryptionKeyName,
			EncryptionPassword: encryptionKeyPassword,
			Active:             key.Active,
		}

		credhubConfig.Encryption.Keys = append(credhubConfig.Encryption.Keys, configKey)

	}

	switch boshConfig.DataStorage.Type {
	case "in-memory":
		credhubConfig.Flyway.Locations = config.H2MigrationsPath
	case "mysql":
		credhubConfig.Flyway.Locations = config.MysqlMigrationsPath
		connectionString := config.MysqlConnectionString
		if boshConfig.DataStorage.RequireTLS {
			connectionString = config.MysqlTlsConnectionString
		}
		credhubConfig.Spring.Datasource.URL = fmt.Sprintf(connectionString,
			boshConfig.DataStorage.Host, boshConfig.DataStorage.Port, boshConfig.DataStorage.Database)
		credhubConfig.Spring.Datasource.Username = boshConfig.DataStorage.Username
		credhubConfig.Spring.Datasource.Password = boshConfig.DataStorage.Password
	case "postgres":
		credhubConfig.Flyway.Locations = config.PostgresMigrationsPath
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
