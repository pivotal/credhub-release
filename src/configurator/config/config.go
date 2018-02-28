package config

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	DefaultCipherSuites = "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256, TLS_DHE_RSA_WITH_AES_256_GCM_SHA384, TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256, TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
	Java7CipherSuites   = DefaultCipherSuites + ", TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA, TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA"

	ConfigPath            = "/var/vcap/jobs/credhub/config"
	MtlsTrustStorePath    = ConfigPath + "/mtls_trust_store.jks"
	DefaultTrustStorePath = ConfigPath + "/trust_store.jks"

	TrustStorePasswordPlaceholder     = "TRUST_STORE_PASSWORD_PLACEHOLDER"
	MtlsTrustStorePasswordPlaceholder = "MTLS_TRUST_STORE_PASSWORD_PLACEHOLDER"
)

var (
	FlywayMigrationsPath   = []string{"classpath:/db/migration/common"}
	H2MigrationsPath       = append(FlywayMigrationsPath, "classpath:/db/migration/h2")
	MysqlMigrationsPath    = append(FlywayMigrationsPath, "classpath:/db/migration/mysql")
	PostgresMigrationsPath = append(FlywayMigrationsPath, "classpath:/db/migration/postgres")

	PostgresConnectionString    = "jdbc:postgresql://%s:%s/%s?autoReconnect=true"
	PostgresTlsConnectionString = PostgresConnectionString + "&ssl=true"

	MysqlConnectionString    = "jdbc:mariadb://%s:%s/%s?autoReconnect=true"
	MysqlTlsConnectionString = MysqlConnectionString +
		"&useSSL=true&requireSSL=true&verifyServerCertificate=true" +
		"&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2" +
		"&trustCertificateKeyStorePassword=TRUST_STORE_PASSWORD_PLACEHOLDER" +
		"&trustCertificateKeyStoreUrl=" + DefaultTrustStorePath
)

type BoshConfig struct {
	Port                   json.Number
	Java7TlsCiphersEnabled bool `json:"java7_tls_ciphers_enabled"`
	Authentication         struct {
		MutualTLS struct {
			TrustedCAs []string `json:"trusted_cas"`
		} `json:"mutual_tls"`
		UAA struct {
			Enabled     bool
			Url         string
			InternalUrl string `json:"internal_url"`
		}
	}
	Authorization struct {
		ACLs struct {
			Enabled bool
		} `json:"acls"`
	}
	DataStorage struct {
		Type       string
		Host       string
		Database   string
		Username   string
		Password   string
		Port       json.Number
		RequireTLS bool `json:"require_tls"`
	} `json:"data_storage"`
	Encryption struct {
		Keys      []BoshKey
		Providers []BoshProvider
	}
	Bootstrap bool
}

type BoshKey struct {
	ProviderName       string `json:"provider_name"`
	Active             bool
	EncryptionKeyName  string        `json:"encryption_key_name"`  //deprecated
	EncryptionPassword string        `json:"encryption_password"` //deprecated
	KeyProperties      KeyProperties `json:"key_properties"`
}

type KeyProperties struct {
	EncryptionKeyName  string `json:"encryption_key_name"`
	EncryptionPassword string `json:"encryption_password"`
}

type BoshProvider struct {
	Name                 string
	Type                 string
	Partition            string               // deprecated
	PartitionPassword    string               `json:"partition_password"` // deprecated
	ConnectionProperties ConnectionProperties `json:"connection_properties"`
}

type ConnectionProperties struct {
	Partition         string
	PartitionPassword string `json:"partition_password"`
}

type CredhubConfig struct {
	Server struct {
		Port int64
		SSL  SSLConfig
	}
	Security struct {
		OAuth2 struct {
			Enabled bool
		}
		Authorization struct {
			ACLs struct {
				Enabled bool
			}
		}
	}
	AuthServer AuthServerConfig `yaml:"auth_server"`
	Spring     struct {
		JPA struct {
			Hibernate struct {
				DDLAuto string `yaml:"ddl_auto"`
			}
		}
		Datasource SpringDatasource
	}
	Flyway struct {
		Locations []string
		Enabled   bool
	}
	Encryption struct {
		KeyCreationEnabled bool `yaml:"key_creation_enabled"`

		Keys []Key
	}

	Hsm struct {
		Partition         string `yaml:"partition,omitempty"`
		PartitionPassword string `yaml:"partition_password,omitempty"`
	}

	Logging struct {
		Config string
	}
}

type Key struct {
	ProviderType       string `yaml:"provider_type"`
	EncryptionPassword string `yaml:"encryption_password,omitempty"`
	EncryptionKeyName  string `yaml:"encryption_key_name,omitempty"`
	Active             bool   `yaml:"active"`
}

type SSLConfig struct {
	Enabled          bool
	KeyStore         string `yaml:"key_store"`
	KeyPassword      string `yaml:"key_password"`
	KeyAlias         string `yaml:"key_alias"`
	Ciphers          string
	EnabledProtocols string `yaml:"enabled_protocols"`

	ClientAuth         string `yaml:"client_auth,omitempty"`
	TrustStore         string `yaml:"trust_store,omitempty"`
	TrustStorePassword string `yaml:"trust_store_password,omitempty"`
	TrustStoreType     string `yaml:"trust_store_type,omitempty"`
}

type AuthServerConfig struct {
	URL         string `yaml:"url"`
	InternalURL string `yaml:"internal_url,omitempty"`

	TrustStore         string `yaml:"trust_store"`
	TrustStorePassword string `yaml:"trust_store_password"`
}

type SpringDatasource struct {
	Username string
	Password string
	URL      string
}

func NewDefaultCredhubConfig() CredhubConfig {
	config := CredhubConfig{}

	config.Server.SSL = SSLConfig{
		Enabled:          true,
		KeyStore:         ConfigPath + "/cacerts.jks",
		KeyPassword:      "KEY_STORE_PASSWORD_PLACEHOLDER",
		KeyAlias:         "credhub_tls_cert",
		Ciphers:          DefaultCipherSuites,
		EnabledProtocols: "TLSv1.2",
	}

	config.Spring.JPA.Hibernate.DDLAuto = "validate"
	config.Logging.Config = ConfigPath + "/log4j2.properties"

	return config
}

type BoshConfigGenerator interface {
	NewBoshConfig(filePath string) BoshConfig
}

func (cc CredhubConfig) PopulateConfig(bc BoshConfigGenerator) error {
	boshConfig := bc.NewBoshConfig("blah")

	port, err := boshConfig.Port.Int64()
	if err != nil {
		return err
	}

	cc.Server.Port = port
	cc.Security.Authorization.ACLs.Enabled = boshConfig.Authorization.ACLs.Enabled

	if boshConfig.Java7TlsCiphersEnabled {
		cc.Server.SSL.Ciphers = Java7CipherSuites
	}

	if len(boshConfig.Authentication.MutualTLS.TrustedCAs) > 0 {
		cc.Server.SSL.ClientAuth = "want"
		cc.Server.SSL.TrustStore = ConfigPath + "/mtls_trust_store.jks"
		cc.Server.SSL.TrustStorePassword = "MTLS_TRUST_STORE_PASSWORD_PLACEHOLDER"
		cc.Server.SSL.TrustStoreType = "JKS"
	}

	if boshConfig.Authentication.UAA.Enabled {
		cc.Security.OAuth2.Enabled = true
		cc.AuthServer.URL = boshConfig.Authentication.UAA.Url
		cc.AuthServer.TrustStore = DefaultTrustStorePath
		cc.AuthServer.TrustStorePassword = TrustStorePasswordPlaceholder
		cc.AuthServer.InternalURL = boshConfig.Authentication.UAA.InternalUrl
	}

	if boshConfig.Bootstrap {
		cc.Encryption.KeyCreationEnabled = true
		cc.Flyway.Enabled = true
	}

	for _, key := range boshConfig.Encryption.Keys {
		var providerType string

		for _, provider := range boshConfig.Encryption.Providers {
			if provider.Name == key.ProviderName {
				providerType = provider.Type

				if provider.Type == "hsm" {
					if provider.ConnectionProperties.Partition == "" && provider.ConnectionProperties.PartitionPassword == "" {
						cc.Hsm.Partition = provider.Partition
						cc.Hsm.PartitionPassword = provider.PartitionPassword
					} else {
						cc.Hsm.Partition = provider.ConnectionProperties.Partition
						cc.Hsm.PartitionPassword = provider.ConnectionProperties.PartitionPassword
					}
				}
				break
			}

		}

		var encryptionKeyName string
		var encryptionKeyPassword string
		if key.KeyProperties.EncryptionKeyName == "" && key.KeyProperties.EncryptionPassword == "" {
			encryptionKeyName = key.EncryptionKeyName
			encryptionKeyPassword = key.EncryptionPassword
		} else {
			encryptionKeyName = key.KeyProperties.EncryptionKeyName
			encryptionKeyPassword = key.KeyProperties.EncryptionPassword
		}

		key := Key{
			ProviderType:       providerType,
			EncryptionKeyName:  encryptionKeyName,
			EncryptionPassword: encryptionKeyPassword,
			Active:             key.Active,
		}

		cc.Encryption.Keys = append(cc.Encryption.Keys, key)

	}

	switch boshConfig.DataStorage.Type {
	case "in-memory":
		cc.Flyway.Locations = H2MigrationsPath
	case "mysql":
		cc.Flyway.Locations = MysqlMigrationsPath
		connectionString := MysqlConnectionString
		if boshConfig.DataStorage.RequireTLS {
			connectionString = MysqlTlsConnectionString
		}
		cc.Spring.Datasource.URL = fmt.Sprintf(connectionString,
			boshConfig.DataStorage.Host, boshConfig.DataStorage.Port, boshConfig.DataStorage.Database)
		cc.Spring.Datasource.Username = boshConfig.DataStorage.Username
		cc.Spring.Datasource.Password = boshConfig.DataStorage.Password
	case "postgres":
		cc.Flyway.Locations = PostgresMigrationsPath
		connectionString := PostgresConnectionString
		if boshConfig.DataStorage.RequireTLS {
			connectionString = PostgresTlsConnectionString
		}
		cc.Spring.Datasource.URL = fmt.Sprintf(connectionString,
			boshConfig.DataStorage.Host, boshConfig.DataStorage.Port, boshConfig.DataStorage.Database)
		cc.Spring.Datasource.Username = boshConfig.DataStorage.Username
		cc.Spring.Datasource.Password = boshConfig.DataStorage.Password
	default:
		fmt.Fprintln(os.Stderr, `credhub.data_storage.type must be set to "mysql", "postgres", or "in-memory".`)
		os.Exit(1)
	}
	return err
}
