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
	MysqlTlsDisableHostnameVerification = "&disableSslHostnameVerification=true"
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
		Permissions []BoshPermission `json:"permissions"`
	}
	DataStorage struct {
		Type                 string
		Host                 string
		Database             string
		Username             string
		Password             string
		Port                 json.Number
		RequireTLS           bool `json:"require_tls"`
		HostnameVerification struct {
			Enabled bool
		} `json:"hostname_verification"`
	} `json:"data_storage"`
	Encryption struct {
		Keys      []BoshKey
		Providers []BoshProvider
	}
	Bootstrap bool
}

type BoshPermission struct {
	Path       string   `json:"path"`
	Actors     []string `json:"actors"`
	Operations []string `json:"operations"`
}

type BoshKey struct {
	ProviderName  string `json:"provider_name"`
	Active        bool
	KeyProperties KeyProperties `json:"key_properties"`
}

type KeyProperties struct {
	EncryptionKeyName  string `json:"encryption_key_name"`
	EncryptionPassword string `json:"encryption_password"`
}

type BoshProvider struct {
	Name                 string
	Type                 string
	ConnectionProperties ProviderConfig `json:"connection_properties"`
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
			Permissions []Permission
		}
	}
	AuthServer AuthServerConfig `yaml:"auth-server"`
	Spring     struct {
		JPA struct {
			Hibernate struct {
				DDLAuto string `yaml:"ddl_auto"`
			}
		}
		Datasource SpringDatasource
		Flyway     struct {
			Locations []string
			Enabled   bool
		}
	}
	Encryption struct {
		KeyCreationEnabled bool `yaml:"key_creation_enabled"`
		Providers          []Provider
	}

	Logging struct {
		Config string
	}
}

type Permission struct {
	Path       string   `yaml:"path,omitempty"`
	Actors     []string `yaml:"actors,omitempty"`
	Operations []string `yaml:"operations,omitempty"`
}

type Key struct {
	EncryptionPassword string `yaml:"encryption_password,omitempty"`
	EncryptionKeyName  string `yaml:"encryption_key_name,omitempty"`
	Active             bool   `yaml:"active"`
}

type Provider struct {
	ProviderName string         `yaml:"provider_name,omitempty"`
	ProviderType string         `yaml:"provider_type,omitempty"`
	Keys         []Key          `yaml:"keys,omitempty"`
	Config       ProviderConfig `yaml:"configuration,omitempty"`
}

type ProviderConfig struct {
	Partition         string `yaml:"partition,omitempty"`
	PartitionPassword string `yaml:"partition_password,omitempty" json:"partition_password"`
	Host              string `yaml:"host,omitempty"`
	Port              int    `yaml:"port,omitempty"`
	ServerCa          string `yaml:"server_ca,omitempty" json:"server_ca"`
	ClientCert        string `yaml:"client_certificate,omitempty" json:"client_certificate"`
	ClientKey         string `yaml:"client_key,omitempty" json:"client_key"`
	Endpoint          string `yaml:"endpoint,omitempty" json:"endpoint"`
}

type SSLConfig struct {
	Enabled          bool
	KeyStore         string `yaml:"key_store"`
	KeyStorePassword string `yaml:"key_store_password"`
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
		KeyStorePassword: "KEY_STORE_PASSWORD_PLACEHOLDER",
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
