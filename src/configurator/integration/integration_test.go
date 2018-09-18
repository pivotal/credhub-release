package integration_test

import (
	"configurator/config"
	"os/exec"

	"encoding/json"

	"bytes"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"
	"github.com/pkg/errors"
	"gopkg.in/yaml.v2"
)

var _ = Describe("Configurator", func() {
	var (
		pathToCLI string
		cli       *ConfiguratorCLI
	)

	BeforeSuite(func() {
		var err error
		pathToCLI, err = Build("configurator")
		Ω(err).ShouldNot(HaveOccurred())
	})

	BeforeEach(func() {
		cli = &ConfiguratorCLI{
			Path: pathToCLI,
		}
		cli.BoshConfig.DataStorage.Type = "mysql"
	})

	AfterSuite(func() {
		CleanupBuildArtifacts()
	})

	Describe("usage", func() {
		It("prints the usage when called with no args", func() {
			session, err := cli.RunWithoutConfig()
			Expect(err).NotTo(HaveOccurred())

			Eventually(session).Should(Exit(1))
			Eventually(session.Err).Should(gbytes.Say("Usage: <json> | configurator"))
		})
	})

	It("outputs application config", func() {
		cli.BoshConfig.Port = "8844"

		result, err := runCli(cli, "")
		Expect(err).NotTo(HaveOccurred())

		expected := config.NewDefaultCredhubConfig()
		expected.Server.Port = 8844
		Expect(result.Server.Port).To(Equal(int64(8844)))
	})

	Context("when Java 7 ciphers are enabled", func() {
		It("includes Java 7 cipher suites", func() {
			cli.BoshConfig.Java7TlsCiphersEnabled = true
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Server.SSL.Ciphers).To(Equal(config.Java7CipherSuites))
		})
	})

	Context("when mutual TLS is enabled", func() {
		It("includes client trust store properties", func() {
			cli.BoshConfig.Authentication.MutualTLS.TrustedCAs = []string{"some-ca"}
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expected := config.NewDefaultCredhubConfig().Server.SSL
			expected.ClientAuth = "want"
			expected.TrustStore = config.MtlsTrustStorePath
			expected.TrustStorePassword = config.MtlsTrustStorePasswordPlaceholder
			expected.TrustStoreType = "JKS"

			Expect(result.Server.SSL).To(Equal(expected))
		})
	})

	Context("when the UAA is enabled", func() {
		It("includes auth server properties", func() {
			cli.BoshConfig.Authentication.UAA.Enabled = true
			cli.BoshConfig.Authentication.UAA.Url = "some-uaa-url"
			cli.BoshConfig.Authentication.UAA.InternalUrl = "some-internal-url"
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			authServerConfig := config.AuthServerConfig{
				URL:                "some-uaa-url",
				InternalURL:        "some-internal-url",
				TrustStore:         config.DefaultTrustStorePath,
				TrustStorePassword: config.TrustStorePasswordPlaceholder,
			}
			Expect(result.AuthServer).To(Equal(authServerConfig))
		})
	})

	Context("when ACLs are enabled", func() {
		It("includes ACLs", func() {
			cli.BoshConfig.Authorization.ACLs.Enabled = true
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			Expect(result.Security.Authorization.ACLs.Enabled).To(BeTrue())
		})
	})

	Context("when the storage is set to in-memory", func() {
		It("adds flyway migrations to the flyway config", func() {
			cli.BoshConfig.DataStorage.Type = "in-memory"
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Spring.Flyway.Locations).To(Equal(config.H2MigrationsPath))
		})
	})

	Context("when the storage is set to mysql", func() {
		BeforeEach(func() {
			cli.BoshConfig.DataStorage.Type = "mysql"
			cli.BoshConfig.DataStorage.Port = "3306"
			cli.BoshConfig.DataStorage.Database = "prod"
			cli.BoshConfig.DataStorage.Host = "localhost"
			cli.BoshConfig.DataStorage.Username = "user"
			cli.BoshConfig.DataStorage.Password = "pass"
		})

		It("sets the database properties", func() {
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Spring.Datasource).To(Equal(config.SpringDatasource{
				Username: "user",
				Password: "pass",
				URL:      "jdbc:mariadb://localhost:3306/prod?autoReconnect=true",
			}))
			Expect(result.Spring.Flyway.Locations).To(Equal(config.MysqlMigrationsPath))
		})

		Context("when TLS is enabled", func() {
			It("sets the TLS params in the connection URL", func() {
				cli.BoshConfig.DataStorage.RequireTLS = true
				cli.BoshConfig.DataStorage.HostnameVerification.Enabled = true

				result, err := runCli(cli, "")
				Expect(err).NotTo(HaveOccurred())
				Expect(result.Spring.Datasource.URL).To(Equal(
					"jdbc:mariadb://localhost:3306/prod?" +
						"autoReconnect=true&useSSL=true&requireSSL=true&" +
						"verifyServerCertificate=true&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2&" +
						"trustCertificateKeyStorePassword=TRUST_STORE_PASSWORD_PLACEHOLDER&" +
						"trustCertificateKeyStoreUrl=/var/vcap/jobs/credhub/config/trust_store.jks",
				))
			})

			Context("when hostname verification is disabled", func() {
				It("disables hostname verification in the connection URL", func() {
					cli.BoshConfig.DataStorage.RequireTLS = true
					cli.BoshConfig.DataStorage.HostnameVerification.Enabled = false

					result, err := runCli(cli, "")
					Expect(err).NotTo(HaveOccurred())
					Expect(result.Spring.Datasource.URL).To(Equal(
						"jdbc:mariadb://localhost:3306/prod?" +
							"autoReconnect=true&useSSL=true&requireSSL=true&" +
							"verifyServerCertificate=true&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2&" +
							"trustCertificateKeyStorePassword=TRUST_STORE_PASSWORD_PLACEHOLDER&" +
							"trustCertificateKeyStoreUrl=/var/vcap/jobs/credhub/config/trust_store.jks&" +
							"disableSslHostnameVerification=true",
					))
				})
			})
		})
	})

	Context("when the storage is set to postgres", func() {
		BeforeEach(func() {
			cli.BoshConfig.DataStorage.Type = "postgres"
			cli.BoshConfig.DataStorage.Port = "3306"
			cli.BoshConfig.DataStorage.Database = "prod"
			cli.BoshConfig.DataStorage.Host = "localhost"
			cli.BoshConfig.DataStorage.Username = "user"
			cli.BoshConfig.DataStorage.Password = "pass"
		})

		It("sets the database properties", func() {
			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Spring.Datasource).To(Equal(config.SpringDatasource{
				Username: "user",
				Password: "pass",
				URL:      "jdbc:postgresql://localhost:3306/prod?autoReconnect=true",
			}))
			Expect(result.Spring.Flyway.Locations).To(Equal(config.PostgresMigrationsPath))
		})

		Context("when TLS is enabled", func() {
			It("sets the TLS params in the connection URL", func() {
				cli.BoshConfig.DataStorage.RequireTLS = true
				result, err := runCli(cli, "")
				Expect(err).NotTo(HaveOccurred())
				Expect(result.Spring.Datasource.URL).To(Equal(
					"jdbc:postgresql://localhost:3306/prod?autoReconnect=true&ssl=true",
				))
			})
		})
	})

	It("enables flyway and key creation only on the bootstrap node", func() {
		cli.BoshConfig.Bootstrap = true
		result, err := runCli(cli, "")
		Expect(err).NotTo(HaveOccurred())
		Expect(result.Spring.Flyway.Enabled).To(BeTrue())
		Expect(result.Encryption.KeyCreationEnabled).To(BeTrue())
	})

	Describe("encryption keys", func() {
		It("populates the providers with the keys by mapping name", func() {
			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "hsm",
				},
				{
					Name: "notfoo",
					Type: "internal",
				},
			}

			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
				EncryptionKeyName:  "baz",
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Encryption.Providers).To(HaveLen(2))
			Expect(result.Encryption.Providers[0].Keys).To(HaveLen(1))
			Expect(result.Encryption.Providers[0].ProviderType).To(Equal("hsm"))
			Expect(result.Encryption.Providers[0].Keys[0].EncryptionPassword).To(Equal("bar"))
			Expect(result.Encryption.Providers[0].Keys[0].EncryptionKeyName).To(Equal("baz"))
		})

		It("populates encryption password when key properties is available", func() {

			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "internal",
				},
			}
			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Encryption.Providers).To(HaveLen(1))
			Expect(result.Encryption.Providers[0].Keys).To(HaveLen(1))
			Expect(result.Encryption.Providers[0].ProviderType).To(Equal("internal"))
			Expect(result.Encryption.Providers[0].Keys[0].EncryptionPassword).To(Equal("bar"))
		})

		It("populates encryption key name when key properties is available", func() {
			keyProperties := config.KeyProperties{
				EncryptionKeyName: "bar",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "hsm",
				},
			}
			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())
			Expect(result.Encryption.Providers).To(HaveLen(1))
			Expect(result.Encryption.Providers[0].Keys).To(HaveLen(1))
			Expect(result.Encryption.Providers[0].ProviderType).To(Equal("hsm"))
			Expect(result.Encryption.Providers[0].Keys[0].EncryptionKeyName).To(Equal("bar"))
		})

		It("fails with a useful error message when an encryption key name is provided with internal", func() {
			keyProperties := config.KeyProperties{
				EncryptionKeyName: "bar",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "internal",
				},
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			_, err := runCli(cli, "Internal providers require encryption_password.")
			Expect(err).To(HaveOccurred())
		})

		It("fails with a useful error message when an encryption password is provided with hsm", func() {
			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "hsm",
				},
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			_, err := runCli(cli, "Hsm providers require encryption_key_name.")
			Expect(err).To(HaveOccurred())
		})

		It("fails with a useful error message when an encryption password is provided with kms-plugin", func() {
			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name: "foo",
					Type: "kms-plugin",
				},
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			_, err := runCli(cli, "kms-plugin providers require encryption_key_name.")
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("providers", func() {
		It("throws an error if the client key is not PEM encoded", func() {
			connectionProperties := config.ProviderConfig{
				Partition:         "connection-some-partition",
				PartitionPassword: "connection-some-partition-password",
				ClientCert:        "client cert",
				ClientKey:         "client key",
				Host:              "host",
				Port:              5555,
				ServerCa:          "server ca",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name:                 "foo",
					Type:                 "hsm",
					ConnectionProperties: connectionProperties,
				},
			}

			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
				EncryptionKeyName:  "baz",
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			_, err := runCli(cli, "Provider client private key must be PEM encoded for provider: foo")
			Expect(err).To(HaveOccurred())
		})

		It("populates partition, partition password, host, port, and mtls when connection properties is available using pkcs8 key", func() {
			connectionProperties := config.ProviderConfig{
				Partition:         "connection-some-partition",
				PartitionPassword: "connection-some-partition-password",
				ClientCert:        "client cert",
				ClientKey:         PKCS8KEY,
				Host:              "host",
				Port:              5555,
				ServerCa:          "server ca",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name:                 "foo",
					Type:                 "hsm",
					ConnectionProperties: connectionProperties,
				},
			}

			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
				EncryptionKeyName:  "baz",
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expectedProperties := config.ProviderConfig{
				Partition:         connectionProperties.Partition,
				PartitionPassword: connectionProperties.PartitionPassword,
				ClientCert:        connectionProperties.ClientCert,
				ClientKey:         PKCS8KEY,
				Host:              connectionProperties.Host,
				Port:              connectionProperties.Port,
				ServerCa:          connectionProperties.ServerCa,
			}
			Expect(result.Encryption.Providers[0].Config).To(Equal(expectedProperties))
		})

		It("populates partition, partition password, host, port, and mtls when connection properties is available", func() {
			connectionProperties := config.ProviderConfig{
				Partition:         "connection-some-partition",
				PartitionPassword: "connection-some-partition-password",
				ClientCert:        "client cert",
				ClientKey:         CLIENTKEY,
				Host:              "host",
				Port:              5555,
				ServerCa:          "server ca",
				Endpoint:          "sample socket",
			}

			cli.BoshConfig.Encryption.Providers = []config.BoshProvider{
				{
					Name:                 "foo",
					Type:                 "hsm",
					ConnectionProperties: connectionProperties,
				},
			}

			keyProperties := config.KeyProperties{
				EncryptionPassword: "bar",
				EncryptionKeyName:  "baz",
			}

			cli.BoshConfig.Encryption.Keys = []config.BoshKey{
				{
					ProviderName:  "foo",
					KeyProperties: keyProperties,
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expectedProperties := config.ProviderConfig{
				Partition:         connectionProperties.Partition,
				PartitionPassword: connectionProperties.PartitionPassword,
				ClientCert:        connectionProperties.ClientCert,
				ClientKey:         PKCS8KEY,
				Host:              connectionProperties.Host,
				Port:              connectionProperties.Port,
				ServerCa:          connectionProperties.ServerCa,
				Endpoint:          connectionProperties.Endpoint,
			}
			Expect(result.Encryption.Providers[0].Config).To(Equal(expectedProperties))
		})

	})

	Describe("authorization", func() {
		It("populates the permissions when they are available", func() {
			cli.BoshConfig.Authorization.Permissions = []config.BoshPermission{
				{
					Path:       "foo",
					Actors:     []string{"bar"},
					Operations: []string{"baz"},
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expectedPermission := config.Permission{
				"foo",
				[]string{"bar"},
				[]string{"baz"},
			}

			Expect(result.Security.Authorization.Permissions).To(Equal([]config.Permission{expectedPermission}))

		})

		It("populates the permission for multiple actors", func() {
			cli.BoshConfig.Authorization.Permissions = []config.BoshPermission{
				{
					Path:       "foo",
					Actors:     []string{"bar", "bar2"},
					Operations: []string{"baz"},
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expectedPermission := config.Permission{
				"foo",
				[]string{"bar", "bar2"},
				[]string{"baz"},
			}

			Expect(result.Security.Authorization.Permissions).To(Equal([]config.Permission{expectedPermission}))
		})

		It("populates the permission for multiple permissions", func() {
			cli.BoshConfig.Authorization.Permissions = []config.BoshPermission{
				{
					Path:       "foo",
					Actors:     []string{"bar"},
					Operations: []string{"baz"},
				},

				{
					Path:       "foo2",
					Actors:     []string{"bar2", "bar3"},
					Operations: []string{"baz2"},
				},
			}

			result, err := runCli(cli, "")
			Expect(err).NotTo(HaveOccurred())

			expectedPermission1 := config.Permission{
				"foo",
				[]string{"bar"},
				[]string{"baz"},
			}

			expectedPermission2 := config.Permission{
				"foo2",
				[]string{"bar2", "bar3"},
				[]string{"baz2"},
			}

			Expect(result.Security.Authorization.Permissions).To(Equal([]config.Permission{expectedPermission1, expectedPermission2}))
		})
	})

})

func runCli(cli *ConfiguratorCLI, errorMessage string) (*config.CredhubConfig, error) {
	session, err := cli.RunWithConfig()
	if err != nil {
		return nil, err
	}

	if errorMessage == "" {
		EventuallyWithOffset(1, session).Should(Exit(0))
	} else {
		EventuallyWithOffset(1, session).Should(Exit())
		Expect(string(session.Err.Contents())).To(ContainSubstring(errorMessage))
		return nil, errors.New(errorMessage)
	}

	var result config.CredhubConfig
	Expect(yaml.Unmarshal(session.Out.Contents(), &result)).To(Succeed())

	return &result, err
}

type ConfiguratorCLI struct {
	Path       string
	BoshConfig config.BoshConfig
}

func (c *ConfiguratorCLI) RunWithoutConfig() (*Session, error) {
	configuratorCmd := exec.Command(c.Path, "/tmp/some-file")
	return Start(configuratorCmd, GinkgoWriter, GinkgoWriter)
}

func (c *ConfiguratorCLI) RunWithConfig() (*Session, error) {
	configJson, err := json.Marshal(&c.BoshConfig)
	if err != nil {
		return nil, err
	}
	configuratorCmd := exec.Command(c.Path, "/tmp/some-file")
	configuratorCmd.Stdin = bytes.NewReader(configJson)

	return Start(configuratorCmd, GinkgoWriter, GinkgoWriter)
}
