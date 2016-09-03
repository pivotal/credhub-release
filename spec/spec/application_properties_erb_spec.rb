require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'

def render_erb(data_storage_yaml, tls_yaml = 'tls: { certificate: "foo", private_key: "bar" }', log_level = 'info')
  option_yaml = <<-EOF
        properties:
          credhub:
            port: 9000
            hsm:
              partition: "partname"
              partition_password: "partpass"
              encryption_key_name: "keyname"
            user_management:
              uaa:
                url: "my_uaa_url"
                verification_key: |
                  line 1
                  line 2
            #{tls_yaml.empty? ? '' : tls_yaml}
            data_storage:
              #{data_storage_yaml}
            log_level: #{log_level}

  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/application.properties.erb")
end

RSpec.describe "the template" do
  context "regarding storage types" do
    it "prints error when credhub.data_storage.type is invalid" do
      expect {render_erb('{ type: "foo", database: "my_db_name" }')}
          .to raise_error('credhub.data_storage.type must be set to "mysql", "postgres", or "in-memory".')
    end
  end

  context "with in-memory" do
    it "sets url correctly for in-memory" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }')
      expect(result).to include "jdbc:h2:mem:my_db_name"
    end

    it "renders verification_key as one long string" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }')
      expect(result).to include "line 1line 2"
    end

    it "sets flyway location to be h2" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }')
      expect(result).to include "flyway.locations=classpath:/db/migration/common,classpath:/db/migration/h2"
    end
  end

  context "with Postgres" do
    it "sets url correctly for Postgres" do
      result = render_erb('{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name" }')
      expect(result).to include "jdbc:postgresql://my_host:1234/my_db_name"
      expect(result).to include "autoReconnect=true"
    end

    it "sets flyway location to be postgres" do
      result = render_erb('{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name" }')
      expect(result).to include "flyway.locations=classpath:/db/migration/common,classpath:/db/migration/postgres"
    end
  end

  context "with MySQL" do
    it "sets url correctly for MySQL without TLS" do
      result = render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: false }')
      expect(result).to include "jdbc:mysql://my_host:1234/my_db_name"
      expect(result).to include "?autoReconnect=true"
      expect(result).not_to include "useSSL="
      expect(result).not_to include "requireSSL="
      expect(result).not_to include "verifyServerCertificate="
    end

    it "sets flyway location to be mysql" do
      result = render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: false }')
      expect(result).to include "flyway.locations=classpath:/db/migration/common,classpath:/db/migration/mysql"
    end

    it "sets url correctly for MySQL with TLS but without custom certificate" do
      result = render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: true }')
      expect(result).to include "jdbc:mysql://my_host:1234/my_db_name"
      expect(result).to include "?autoReconnect=true"
      expect(result).to include "&useSSL=true"
      expect(result).to include "&requireSSL=true"
      expect(result).to include "&verifyServerCertificate=true"
    end

    it "sets url correctly for MySQL when tls_ca is set" do
      result = render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: true, tls_ca: "something" }')
      expect(result).to include "&useSSL=true"
      expect(result).to include "&requireSSL=true"
      expect(result).to include "&verifyServerCertificate=true"
      expect(result).to include "&trustCertificateKeyStorePassword=changeit"
      expect(result).to include "&trustCertificateKeyStoreUrl=file:///var/vcap/jobs/credhub/config/db_trust_store.jks"
    end

    it "prints error when require_tls is not a boolean type" do
      expect {render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: "true" }')}
          .to raise_error("credhub.data_storage.require_tls (true) must be set to \"true\" or \"false\".")
    end
  end

  it "adds SSL properties" do
    result = render_erb('{ type: "in-memory", database: "my_db_name" }')
    expect(result).to include "server.ssl.enabled"
    expect(result).to include "server.ssl.key-store"
    expect(result).to include "server.ssl.key-password"
    expect(result).to include "server.ssl.key-alias"
    expect(result).to include "server.ssl.ciphers"
  end

  context "with logging" do
    it "sets log configuration path" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }', '', 'info')
      expect(result).to include "logging.config=/var/vcap/jobs/credhub/config/log4j2.properties"
    end
  end
end
