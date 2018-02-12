package main

import (
	"configurator/config"
	"encoding/json"
	"fmt"
	"os"

	"gopkg.in/yaml.v2"
)

func main() {
	fileInfo, err := os.Stdin.Stat()
	if err != nil {
		panic(err)
	}

	if fileInfo.Size() == 0 {
		fmt.Fprintln(os.Stderr, "Usage: configurator <config-json>")
		os.Exit(1)
	}

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
