require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_erb_to_yaml(data_storage_yaml,
                       tls_yaml: nil,
                       keys_yaml: nil,
                       log_level: nil,
                       mtls_yaml: nil,
                       option_yaml: nil,
                       provider_type_yaml: nil,
                       acls_enabled: false)
  data_storage_yaml ||= '{ type: "in-memory", database: "my_db_name" }'
  tls_yaml ||= 'tls: { certificate: "foo", private_key: "bar" }'
  keys_yaml ||= '[{provider_name: "active_hsm", encryption_key_name: "active_keyname", active: true},
                  {provider_name: "active_hsm", encryption_key_name: "another_keyname"}]'
  log_level ||= 'info'
  provider_type_yaml ||= 'hsm'
  acls_enabled ||= false
  option_yaml ||= <<-EOF
        properties:
          credhub:
            encryption:
              keys: #{keys_yaml}
              providers:
                - name: old_hsm
                  type: #{provider_type_yaml}
                  partition: "old_partition"
                  partition_password: "old_partpass"
                - name: active_hsm
                  type: #{provider_type_yaml}
                  partition: "active_partition"
                  partition_password: "active_partpass"
            port: 9000
            authentication:
              uaa:
                url: "my_uaa_url"
                verification_key: |
                  line 1
                  line 2
              #{mtls_yaml ? mtls_yaml : ''}
            authorization:
              acls:
                enabled: #{acls_enabled}
            #{tls_yaml.empty? ? '' : tls_yaml}
            data_storage: #{data_storage_yaml}
            log_level: #{log_level}

  EOF
  options = {:context => YAML.load(option_yaml).to_json}

  renderer = Bosh::Template::Renderer.new(options)
  renderer.render('../jobs/credhub/templates/application.yml.erb')
end

def render_erb_to_hash(data_storage_yaml, **kwargs)
  rendered_application_yaml = render_erb_to_yaml(data_storage_yaml, **kwargs)

  YAML.load(rendered_application_yaml)
end

def parse_database_url(url_string)
  url_hash = {}
  url = URI.parse(url_string.gsub('jdbc:', '')) # URI.parse isn't smart enough for JDBC schemes

  url_hash['scheme'] = url_string.slice(/(.*):\/\//) # But we are smart enough for JDBC
  url_hash['host'] = url.host
  url_hash['port'] = url.port
  url_hash['path'] = url.path
  url_hash['query_params'] = CGI.parse(url.query)

  url_hash
end

RSpec.describe 'the template' do
  it 'sets the CredHub port correctly' do
    result = render_erb_to_hash('{ type: "in-memory" }')
    expect(result['server']['port']).to eq 9000
  end

  describe 'authentication' do
    it 'renders verification_key as a multiline string' do
      result = render_erb_to_hash('{ type: "in-memory" }')
      expect(result['security']['oauth2']['resource']['jwt']['key_value']).to eq "line 1\nline 2\n"
    end

    it 'sets uaa as the auth server' do
      result = render_erb_to_hash('{ type: "in-memory" }')
      expect(result['auth_server']['url']).to eq 'my_uaa_url'
    end
  end

  describe 'authorization' do
    it 'disables ACLs by default' do
      result = render_erb_to_hash('{ type: "in-memory" }', acls_enabled: false)
      expect(result['security']['authorization']['acls']['enabled']).to eq false
    end

    it 'enables ACLs when credhub.authorization.acls.enabled is set to true' do
      result = render_erb_to_hash('{ type: "in-memory" }', acls_enabled: true)
      expect(result['security']['authorization']['acls']['enabled']).to eq true
    end
  end

  it 'specifies whether flyway should be enabled' do
    result = render_erb_to_hash('{ type: "in-memory" }')
    expect(result['flyway']['enabled']).to eq false
  end

  describe 'setting the database type' do
    context 'with in-memory' do
      it 'sets does not include username, password, database, host and port properties' do
        result = render_erb_to_hash('{ type: "in-memory" }')
        expect(result).to_not include 'username:'
        expect(result).to_not include 'password:'
        expect(result).to_not include 'database:'
        expect(result).to_not include 'host:'
        expect(result).to_not include 'port:'
      end

      it 'sets flyway location to be h2' do
        result = render_erb_to_hash(
            '{ type: "in-memory" }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/h2)
      end
    end

    context 'with Postgres' do
      it 'sets databse url correctly' do
        result = render_erb_to_hash(
            '{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password" }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:postgresql://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']
      end

      it 'sets username' do
        result = render_erb_to_hash(
            '{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password" }')
        expect(result['spring']['datasource']['username']).to eq('my-username')
      end

      it 'handles passwords with special characters' do
        result = render_erb_to_yaml('{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "\"@,$\'\'%.)\"" }')
        expect(result).to include "password: '\"@,$''''%.)\"'"
      end

      it 'sets flyway location to be postgres' do
        result = render_erb_to_hash(
            '{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password" }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/postgres)
      end
    end

    context 'with MySQL' do
      it 'sets url correctly for MySQL without TLS' do
        result = render_erb_to_hash(
            '{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-user", password: "my-password", require_tls: false }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:mariadb://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']

        expect(url['query_params'].has_key?('useSSL')).to be false
        expect(url['query_params'].has_key?('requireSSL')).to be false
        expect(url['query_params'].has_key?('verifyServerCertificate')).to be false
      end

      it 'handles passwords with special characters' do
        result = render_erb_to_yaml(
            '{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "\"@,$\'\'%.)\"" }')
        expect(result).to include "password: '\"@,$''''%.)\"'"
      end

      it 'sets flyway location to be mysql' do
        result = render_erb_to_hash(
            '{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password" }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/mysql)
      end

      it 'sets url correctly for MySQL with TLS but without custom certificate' do
        result = render_erb_to_hash(
            '{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password", require_tls: true }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:mariadb://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']

        expect(url['query_params']['useSSL']).to eq ['true']
        expect(url['query_params']['requireSSL']).to eq ['true']
        expect(url['query_params']['verifyServerCertificate']).to eq ['true']
      end

      it 'sets url correctly for MySQL when tls_ca is set' do
        result = render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password", require_tls: true, tls_ca: "something" }')

        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['query_params']['trustCertificateKeyStorePassword']).to eq ['KEY_STORE_PASSWORD_PLACEHOLDER']
        expect(url['query_params']['trustCertificateKeyStoreUrl']).to eq ['/var/vcap/jobs/credhub/config/db_trust_store.jks']
      end

      it 'prints error when require_tls is not a boolean type' do
        expect {render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", username: "my-username", password: "my-password", require_tls: "true" }')}
            .to raise_error('credhub.data_storage.require_tls must be set to `true` or `false`.')
      end
    end

    context 'when the database type is invalid' do
      it 'should throw an exception' do
        expect {render_erb_to_hash('{ type: "foo", database: "my_db_name" }')}
            .to raise_error('credhub.data_storage.type must be set to "mysql", "postgres", or "in-memory".')
      end
    end
  end

  it 'adds SSL properties' do
    result = render_erb_to_hash('{ type: "in-memory" }')

    expect(result['server']['ssl']['enabled']).to eq true
    expect(result['server']['ssl']['key_store']).to eq '/var/vcap/jobs/credhub/config/cacerts.jks'
    expect(result['server']['ssl']['key_password']).to eq 'KEY_STORE_PASSWORD_PLACEHOLDER'
    expect(result['server']['ssl']['key_alias']).to eq 'credhub_tls_cert'
    expect(result['server']['ssl']['ciphers']).to eq 'ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384,ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA'
    expect(result['server']['ssl']['enabled_protocols']).to eq 'TLSv1.2'
  end

  describe 'when there is no mutual TLS section' do
    it 'does not mutual TLS properties' do
      result = render_erb_to_hash('{ type: "in-memory" }')

      expect(result['server']['ssl']['trust_store']).to be_nil
      expect(result['server']['ssl']['trust_store_password']).to be_nil
      expect(result['server']['ssl']['trust_store_type']).to be_nil
      expect(result['server']['ssl']['client_auth']).to be_nil
    end
  end

  describe 'when there are no trusted CAs for mutual TLS' do
    it 'adds mutual TLS properties' do
      mutual_tls = 'mutual_tls: { trusted_cas: [] }'
      result = render_erb_to_hash('{ type: "in-memory" }', mtls_yaml: mutual_tls)

      expect(result['server']['ssl']['trust_store']).to be_nil
      expect(result['server']['ssl']['trust_store_password']).to be_nil
      expect(result['server']['ssl']['trust_store_type']).to be_nil
      expect(result['server']['ssl']['client_auth']).to be_nil
    end
  end

  describe 'when there is at least one trusted CA for mTLS' do
    it 'adds mutual TLS properties' do
      mutual_tls = 'mutual_tls: { trusted_cas: ["foo"] }'
      result = render_erb_to_hash('{ type: "in-memory" }', mtls_yaml: mutual_tls)

      expect(result['server']['ssl']['trust_store']).to eq '/var/vcap/jobs/credhub/config/mtls_trust_store.jks'
      expect(result['server']['ssl']['trust_store_password']).to eq 'MTLS_TRUST_STORE_PASSWORD_PLACEHOLDER'
      expect(result['server']['ssl']['trust_store_type']).to eq 'JKS'
      expect(result['server']['ssl']['client_auth']).to eq 'want'
    end
  end

  it 'does not configure Hibernate to destroy the customer data' do
    result = render_erb_to_hash('{ type: "in-memory" }')

    expect(result['spring']['jpa']['hibernate']['ddl_auto']).to eq 'validate'
  end

  it 'sets log configuration path' do
    result = render_erb_to_hash('{ type: "in-memory" }')
    expect(result['logging']['config']).to eq '/var/vcap/jobs/credhub/config/log4j2.properties'
  end

  describe '`encryption:` section' do
    describe '`keys:` section' do
      it 'raises an error when no key has been set active' do
        expect {render_erb_to_hash('{ type: "in-memory" }',
                                   keys_yaml: '[{provider_name: "active_hsm", encryption_key_name: "keyname"}]')}
            .to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
      end

      it 'raises an error when more than one key has been set active' do
        expect {render_erb_to_hash('{ type: "in-memory" }',
                                   keys_yaml: '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "active_hsm", encryption_key_name: "keyname2", active: true}
                                   ]')}
            .to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
      end

      it 'raises an error when keys from more than one provider are present' do
        expect {render_erb_to_hash('{ type: "in-memory" }',
                                   keys_yaml: '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "old_hsm", encryption_key_name: "keyname2", active: false}
                                   ]')}
            .to raise_error('Data migration between encryption providers is not currently supported. Please update your manifest to use a single encryption provider.')
      end

      it 'considers "false" to be false' do
        expect {render_erb_to_hash('{ type: "in-memory" }',
                                   keys_yaml: '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "active_hsm", encryption_key_name: "keyname2", active: false}
                                   ]')}
            .to_not raise_error
      end
    end

    describe '`providers:` section' do
      context 'hsm encryption' do
        it 'should set the hsm properties correctly' do
          result = render_erb_to_hash('{ type: "in-memory" }')

          expect(result['encryption']['provider']).to eq 'hsm'
          expect(result['hsm']['partition']).to eq 'active_partition'
          expect(result['hsm']['partition_password']).to eq 'active_partpass'

          expect(result['encryption']['keys'].length).to eq 2

          first_key = result['encryption']['keys'][0]
          second_key = result['encryption']['keys'][1]

          expect(first_key['encryption_key_name']).to eq 'active_keyname'
          expect(first_key['active']).to eq true

          expect(second_key['encryption_key_name']).to eq 'another_keyname'
          expect(second_key.has_key?('active')).to eq false
        end

        it 'only allows provider types of "internal" and "hsm"' do
          expect {render_erb_to_hash(nil, provider_type_yaml: 'dev_internal')}
              .to raise_error('The provided encryption provider type is not valid. Valid provider types are "hsm" and "internal".')

          %w[hsm internal].each do |valid_type|
            expect { render_erb_to_hash(nil, provider_type_yaml: valid_type) }.to_not raise_error
          end
        end
      end

      context 'internal encryption' do
        context 'with a password' do
          let(:password_base_option_yaml) {
            <<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: active_dev
                  encryption_password: mrcreddymccredhubface
                  active: true
              providers:
                - name: active_dev
                  type: internal
            port: 9000
            authentication:
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

          let(:password_manifest_properties) { YAML.load(password_base_option_yaml) }

          it 'should populate encryption_password' do
            options = {:context => password_manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect(renderer.render('../jobs/credhub/templates/application.yml.erb')).to include('encryption_password: mrcreddymccredhubface')
          end

          it 'should not allow empty string' do
            password_manifest_properties['properties']['credhub']['encryption']['keys'].first['encryption_password'] = ''

            options = {:context => password_manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error('credhub.encryption.encryption_password is not valid (must not be empty if provided).')
          end

          it 'should allow the encryption_password to be omitted' do
            password_manifest_properties['properties']['credhub']['encryption']['keys'].first.delete('encryption_password')

            options = {:context => password_manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to_not raise_error
          end

          it 'should throw an error if encryption_password is < 20 characters' do
            password_manifest_properties['properties']['credhub']['encryption']['keys'].first['encryption_password'] = 'nineteen_not_twenty'

            options = {:context => password_manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error('The encryption_password value must be at least 20 characters in length. Please update and redeploy.')
          end
        end

        context 'with hex keys' do
          let(:base_option_yaml) {
            <<-EOF
          properties:
            credhub:
              encryption:
                keys:
                  - provider_name: active_dev
                    dev_key: "3456abcd1234abcd1234abcd1234abcd"
                    active: true
                  - provider_name: active_dev
                    dev_key: "2345abcd1234abcd1234abcd1234abcd"
                providers:
                  - name: active_dev
                    type: internal
              port: 9000
              authentication:
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

          let(:manifest_properties) { YAML.load(base_option_yaml) }

          it 'fails with a reasonable error message' do
            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error('The key `dev_key` is not supported. You must rotate to using an `encryption_password` prior to upgrading to this version.')
          end
        end
      end
    end
  end
end
