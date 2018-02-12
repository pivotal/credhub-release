package config

import (
	"encoding/json"
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
			InternalUrl string
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
	}
	Encryption struct {
		Keys      []BoshKey
		Providers []struct {
			Type              string
			Partition         string // deprecated
			PartitionPassword string // deprecated

			ConnectionProperties struct {
				Partition         string
				PartitionPassword string
			}
		}
	}
	Bootstrap bool
}

type BoshKey struct {
	ProviderName string
	Active       bool
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

		Keys []struct {
			ProviderType       string `yaml:"provider_type"`
			EncryptionPassword string `yaml:"encryption_password,omitempty"`
			EncryptionKeyName  string `yaml:"encryption_key_name,omitempty"`
		}
	}
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

	return config
}
