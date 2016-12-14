require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_erb(data_storage_yaml, tls_yaml = 'tls: { certificate: "foo", private_key: "bar" }', log_level = 'info')
  option_yaml = <<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: old_hsm
                  encryption_key_name: "old_keyname"
                - provider_name: active_hsm
                  encryption_key_name: "active_keyname"
                  active: true
                - provider_name: active_hsm
                  encryption_key_name: "another_keyname"
              providers:
                - name: old_hsm
                  type: hsm
                  partition: "old_partition"
                  partition_password: "old_partpass"
                - name: active_hsm
                  type: hsm
                  partition: "active_partition"
                  partition_password: "active_partpass"
            port: 9000
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
  renderer.render("../jobs/credhub/templates/application.properties.erb")
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
      password_regex = /server\.ssl\.key-password=(?<password>[a-zA-Z0-9_-]*)/

      result = render_erb('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: true, tls_ca: "something" }')
      password_match = result.match(password_regex)
      expect(password_match).not_to be_nil
      password = password_match[:password]

      expect(result).to include "&useSSL=true"
      expect(result).to include "&requireSSL=true"
      expect(result).to include "&verifyServerCertificate=true"
      expect(result).to include "&trustCertificateKeyStorePassword=#{password}"
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

  it "does not destroy the customer data" do
    result = render_erb('{ type: "in-memory", database: "my_db_name" }')
    expect(result).to include "ddl-auto=validate"
    expect(result).not_to include "ddl-auto=create"
    expect(result).not_to include "ddl-auto=create-drop"
    expect(result).not_to include "ddl-auto=update"
  end

  context "with logging" do
    it "sets log configuration path" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }', '', 'info')
      expect(result).to include "logging.config=/var/vcap/jobs/credhub/config/log4j2.properties"
    end
  end

  context "hsm encryption" do
    it "should set the hsm properties correctly" do
      result = render_erb('{ type: "in-memory", database: "my_db_name" }')

      expect(result).to include "encryption.provider=hsm"
      expect(result).to include "hsm.partition=active_partition"
      expect(result).to include "hsm.partition-password=active_partpass"
      expect(result).to include "hsm.encryption-key-name=active_keyname"
    end
  end


  context "dsm encryption" do
    let(:base_option_yaml) {
      <<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: old_dsm
                  encryption_key_name: "1234abcd1234abcd1234abcd1234abcd"
                - provider_name: active_dsm
                  encryption_key_name: "active_keyname"
                  active: true
                - provider_name: active_dsm
                  encryption_key_name: "abcd1234abcd1234abcd1234abcd1234"
              providers:
                - name: old_dsm
                  type: dsm
                - name: active_dsm
                  type: dsm
            port: 9000
            user_management:
              uaa:
                url: "my_uaa_url"
                verification_key: |
                  line 1
                  line 2
            tls:
              certificate: foo
              private_key: bar
            data_storage:
              type: in-memory
              database: my_db_name
            log_level: info

      EOF
    }
    let(:yaml) { YAML.load(base_option_yaml) }

    it "should set the hsm properties correctly" do
      options = {:context => yaml.to_json}
      renderer = Bosh::Template::Renderer.new(options)
      result = renderer.render("../jobs/credhub/templates/application.properties.erb")

      expect(result).to include "encryption.provider=dsm"
      expect(result).to include "dsm.encryption-key-name=active_keyname"
    end
  end

  context "dev_internal encryption" do
    let(:base_option_yaml) {
      <<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: active_dev
                  dev_key: "XYZZ123412341234"
                  active: true
                - provider_name: old_dev
                  dev_key: "blahblahblah"
              providers:
                - name: active_dev
                  type: dev_internal
                - name: old_dev
                  type: dev_internal
            port: 9000
            user_management:
              uaa:
                url: "my_uaa_url"
                verification_key: |
                  line 1
                  line 2
            tls:
              certificate: foo
              private_key: bar
            data_storage:
              type: in-memory
              database: my_db_name
            log_level: info

      EOF
    }
    let(:yaml) { YAML.load(base_option_yaml) }

    context "validating the dev_key" do
      it "should be valid hexadecimal" do
        yaml['properties']['credhub']['encryption']['keys'].first['dev_key'] = 'xyz'
        options = {:context => yaml.to_json}
        renderer = Bosh::Template::Renderer.new(options)
        expect {
          renderer.render("../jobs/credhub/templates/application.properties.erb")
        }.to raise_error(ArgumentError)
      end

      it "should be 32 characters" do
        yaml['properties']['credhub']['encryption']['keys'].first['dev_key']
        options = {:context => yaml.to_json}
        renderer = Bosh::Template::Renderer.new(options)
        expect {
          renderer.render("../jobs/credhub/templates/application.properties.erb")
        }.to raise_error(ArgumentError)
      end

      it "should not allow empty string" do
        yaml['properties']['credhub']['encryption']['keys'].first['dev_key'] = ''
        options = {:context => yaml.to_json}
        renderer = Bosh::Template::Renderer.new(options)
        expect {
          renderer.render("../jobs/credhub/templates/application.properties.erb")
        }.to raise_error(ArgumentError)
      end

      it "should allow the dev_key to be omitted" do
        yaml['properties']['credhub']['encryption']['keys'].first.delete('dev_key')
        options = {:context => yaml.to_json}
        renderer = Bosh::Template::Renderer.new(options)
        expect {
          renderer.render("../jobs/credhub/templates/application.properties.erb")
        }.to_not raise_error
      end
    end

    it "sets the provider and dev key correctly" do
      yaml['properties']['credhub']['encryption']['keys'].first['dev_key'] = '1234abcd1234abcd1234abcd1234abcd'
      options = {:context => yaml.to_json}
      renderer = Bosh::Template::Renderer.new(options)
      render_erb_value = renderer.render("../jobs/credhub/templates/application.properties.erb")
      expect(render_erb_value).to include "encryption.provider=dev_internal"
      expect(render_erb_value).to include "encryption.dev-key=1234abcd1234abcd1234abcd1234abcd"
    end
  end
end
