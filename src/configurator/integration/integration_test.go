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
			Eventually(session.Err).Should(gbytes.Say("Usage: configurator <config-json>"))
		})
	})

	It("outputs application config", func() {
		cli.BoshConfig.Port = "8844"

		result := runCli(cli)

		expected := config.NewDefaultCredhubConfig()
		expected.Server.Port = 8844
		Expect(result.Server.Port).To(Equal(int64(8844)))
	})

	Context("when Java 7 ciphers are enabled", func() {
		It("includes Java 7 cipher suites", func() {
			cli.BoshConfig.Java7TlsCiphersEnabled = true
			result := runCli(cli)
			Expect(result.Server.SSL.Ciphers).To(Equal(config.Java7CipherSuites))
		})
	})

	Context("when mutual TLS is enabled", func() {
		It("includes client trust store properties", func() {
			cli.BoshConfig.Authentication.MutualTLS.TrustedCAs = []string{"some-ca"}
			result := runCli(cli)

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
			result := runCli(cli)

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
			result := runCli(cli)

			Expect(result.Security.Authorization.ACLs.Enabled).To(BeTrue())
		})
	})

	Context("when the storage is set to in-memory", func() {
		It("adds flyway migrations to the flyway config", func() {
			cli.BoshConfig.DataStorage.Type = "in-memory"
			result := runCli(cli)
			Expect(result.Flyway.Locations).To(Equal(config.H2MigrationsPath))
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
			result := runCli(cli)
			Expect(result.Spring.Datasource).To(Equal(config.SpringDatasource{
				Username: "user",
				Password: "pass",
				URL:      "jdbc:mariadb://localhost:3306/prod?autoReconnect=true",
			}))
			Expect(result.Flyway.Locations).To(Equal(config.MysqlMigrationsPath))
		})

		Context("when TLS is enabled", func() {
			It("sets the TLS params in the connection URL", func() {
				cli.BoshConfig.DataStorage.RequireTLS = true
				result := runCli(cli)
				Expect(result.Spring.Datasource.URL).To(Equal(
					"jdbc:mariadb://localhost:3306/prod?" +
						"autoReconnect=true&useSSL=true&requireSSL=true&" +
						"verifyServerCertificate=true&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2&" +
						"trustCertificateKeyStorePassword=TRUST_STORE_PASSWORD_PLACEHOLDER&" +
						"trustCertificateKeyStoreUrl=/var/vcap/jobs/credhub/config/trust_store.jks",
				))
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
			result := runCli(cli)
			Expect(result.Spring.Datasource).To(Equal(config.SpringDatasource{
				Username: "user",
				Password: "pass",
				URL:      "jdbc:postgresql://localhost:3306/prod?autoReconnect=true",
			}))
			Expect(result.Flyway.Locations).To(Equal(config.PostgresMigrationsPath))
		})

		Context("when TLS is enabled", func() {
			It("sets the TLS params in the connection URL", func() {
				cli.BoshConfig.DataStorage.RequireTLS = true
				result := runCli(cli)
				Expect(result.Spring.Datasource.URL).To(Equal(
					"jdbc:postgresql://localhost:3306/prod?autoReconnect=true&ssl=true",
				))
			})
		})
	})

	It("enables flyway and key creation only on the bootstrap node", func() {
		cli.BoshConfig.Bootstrap = true
		result := runCli(cli)
		Expect(result.Flyway.Enabled).To(BeTrue())
		Expect(result.Encryption.KeyCreationEnabled).To(BeTrue())
	})

	Describe("encryption keys", func() {
		It("populates their type by mapping from the provider", func() {

		})
	})
})

func runCli(cli *ConfiguratorCLI) config.CredhubConfig {
	session, err := cli.RunWithConfig()
	Expect(err).NotTo(HaveOccurred())
	EventuallyWithOffset(1, session).Should(Exit(0))
	var result config.CredhubConfig
	Expect(yaml.Unmarshal(session.Out.Contents(), &result)).To(Succeed())
	return result
}

type ConfiguratorCLI struct {
	Path       string
	BoshConfig config.BoshConfig
}

func (c *ConfiguratorCLI) RunWithoutConfig() (*Session, error) {
	configuratorCmd := exec.Command(c.Path)
	return Start(configuratorCmd, GinkgoWriter, GinkgoWriter)
}

func (c *ConfiguratorCLI) RunWithConfig() (*Session, error) {
	configJson, err := json.Marshal(&c.BoshConfig)
	if err != nil {
		return nil, err
	}
	configuratorCmd := exec.Command(c.Path)
	configuratorCmd.Stdin = bytes.NewReader(configJson)

	return Start(configuratorCmd, GinkgoWriter, GinkgoWriter)
}
