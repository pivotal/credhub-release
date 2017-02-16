require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_erb_to_yaml(data_storage_yaml, tls_yaml = nil, keys_yaml = nil, log_level = nil)
  tls_yaml ||= 'tls: { certificate: "foo", private_key: "bar" }'
  keys_yaml ||= '[{provider_name: "active_hsm", encryption_key_name: "active_keyname", active: true},
                  {provider_name: "active_hsm", encryption_key_name: "another_keyname"}]'
  log_level ||= 'info'
  option_yaml = <<-EOF
        properties:
          credhub:
            encryption:
              keys: #{keys_yaml}
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
            authentication:
              uaa:
                url: "my_uaa_url"
                verification_key: |
                  line 1
                  line 2
            #{tls_yaml.empty? ? '' : tls_yaml}
            data_storage: #{data_storage_yaml}
            log_level: #{log_level}

  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  renderer.render('../jobs/credhub/templates/application.yml.erb')
end

def render_erb_to_hash(data_storage_yaml, tls_yaml = nil, keys_yaml = nil, log_level = nil)
  rendered_application_yaml = render_erb_to_yaml(data_storage_yaml, tls_yaml, keys_yaml, log_level)

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
    result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
    expect(result['server']['port']).to eq 9000
  end

  describe 'authentication' do
    it 'renders verification_key as a multiline string' do
      result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
      expect(result['security']['oauth2']['resource']['jwt']['key-value']).to eq "line 1\nline 2\n"
    end

    it 'sets uaa as the auth server' do
      result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
      expect(result['auth-server']['url']).to eq 'my_uaa_url'
    end
  end

  describe 'setting the database type' do
    context 'with a username' do
      it 'sets the datasource username' do
        result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name", username: "my_username" }')
        expect(result['spring']['datasource']['username']).to eq 'my_username'
      end
    end

    context 'when no datasource username is provided' do
      it 'renders a helpful comment' do
        result = render_erb_to_yaml('{ type: "in-memory", database: "my_db_name" }')
        expect(result).to include 'username: # credhub.data_storage.username not set in your bosh deployment'
      end
    end

    context 'with a password' do
      it 'sets the datasource password' do
        result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name", username: "my_username", password: "my_password" }')
        expect(result['spring']['datasource']['password']).to eq 'my_password'
      end

      it 'explicitly stringifies the password with " marks' do
        result = render_erb_to_yaml('{ type: "in-memory", database: "my_db_name", username: "my_username", password: "my_password" }')
        expect(result).to include 'password: "my_password"'
      end
    end

    context 'when no datasource password is provided' do
      it 'renders a helpful comment' do
        result = render_erb_to_yaml('{ type: "in-memory", database: "my_db_name" }')
        expect(result).to include 'password: # credhub.data_storage.password not set in your bosh deployment'
      end
    end

    context 'with in-memory' do
      it 'sets url correctly for in-memory' do
        result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
        expect(result['spring']['datasource']['url']).to eq 'jdbc:h2:mem:my_db_name'
      end

      it 'sets flyway location to be h2' do
        result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/h2)
      end
    end

    context 'with Postgres' do
      it 'sets url correctly for Postgres' do
        result = render_erb_to_hash('{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name" }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:postgresql://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']
      end

      it 'sets flyway location to be postgres' do
        result = render_erb_to_hash('{ type: "postgres", host: "my_host", port: 1234, database: "my_db_name" }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/postgres)
      end
    end

    context 'with MySQL' do
      it 'sets url correctly for MySQL without TLS' do
        result = render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: false }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:mysql://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']

        expect(url['query_params'].has_key?('useSSL')).to be false
        expect(url['query_params'].has_key?('requireSSL')).to be false
        expect(url['query_params'].has_key?('verifyServerCertificate')).to be false
      end

      it 'sets flyway location to be mysql' do
        result = render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: false }')
        expect(result['flyway']['locations']).to eq %w(classpath:/db/migration/common classpath:/db/migration/mysql)
      end

      it 'sets url correctly for MySQL with TLS but without custom certificate' do
        result = render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: true }')
        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['scheme']).to eq 'jdbc:mysql://'
        expect(url['host']).to eq 'my_host'
        expect(url['port']).to eq 1234
        expect(url['path']).to eq '/my_db_name'
        expect(url['query_params']['autoReconnect']).to eq ['true']

        expect(url['query_params']['useSSL']).to eq ['true']
        expect(url['query_params']['requireSSL']).to eq ['true']
        expect(url['query_params']['verifyServerCertificate']).to eq ['true']
      end

      it 'sets url correctly for MySQL when tls_ca is set' do
        result = render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: true, tls_ca: "something" }')

        url = parse_database_url(result['spring']['datasource']['url'])

        expect(url['query_params']['trustCertificateKeyStorePassword']).to eq ['KEY_STORE_PASSWORD_PLACEHOLDER']
        expect(url['query_params']['trustCertificateKeyStoreUrl']).to eq ['file:///var/vcap/jobs/credhub/config/db_trust_store.jks']
      end

      it 'prints error when require_tls is not a boolean type' do
        expect {render_erb_to_hash('{ type: "mysql", host: "my_host", port: 1234, database: "my_db_name", require_tls: "true" }')}
            .to raise_error('credhub.data_storage.require_tls (true) must be set to "true" or "false".')
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
    result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')

    expect(result['server']['ssl']['enabled']).to eq true
    expect(result['server']['ssl']['key-store']).to eq '/var/vcap/jobs/credhub/config/cacerts.jks'
    expect(result['server']['ssl']['key-password']).to eq 'KEY_STORE_PASSWORD_PLACEHOLDER'
    expect(result['server']['ssl']['key-alias']).to eq 'credhub_tls_cert'
    expect(result['server']['ssl']['ciphers']).to eq 'ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-RSA-AES256-GCM-SHA384'
  end

  it 'does not configure Hibernate to destroy the customer data' do
    result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')

    expect(result['spring']['jpa']['hibernate']['ddl-auto']).to eq 'validate'
  end

  it 'sets log configuration path' do
    result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')
    expect(result['logging']['config']).to eq '/var/vcap/jobs/credhub/config/log4j2.properties'
  end

  describe '`encryption:` section' do
    describe '`keys:` section' do
      it 'raises an error when no key has been set active' do
        expect {render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }', nil, '[{provider_name: "active_hsm", encryption_key_name: "keyname"}]', nil)}
            .to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
      end

      it 'raises an error when more than one key has been set active' do
        expect {render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }',
                                   nil,
                                   '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "active_hsm", encryption_key_name: "keyname2", active: true}
                                   ]',
                                   nil)}
            .to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
      end

      it 'raises an error when keys from more than one provider are present' do
        expect {render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }',
                                   nil,
                                   '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "old_hsm", encryption_key_name: "keyname2", active: false}
                                   ]',
                                   nil)}
            .to raise_error('Data migration between encryption providers is not currently supported. Please update your manifest to use a single encryption provider.')
      end

      it 'considers "false" to be false' do
        expect {render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }',
                                   nil,
                                   '[
                                      {provider_name: "active_hsm", encryption_key_name: "keyname1", active: true},
                                      {provider_name: "active_hsm", encryption_key_name: "keyname2", active: false}
                                   ]',
                                   nil)}
            .to_not raise_error
      end
    end

    describe '`providers:` section' do
      context 'hsm encryption' do
        it 'should set the hsm properties correctly' do
          result = render_erb_to_hash('{ type: "in-memory", database: "my_db_name" }')

          expect(result['encryption']['provider']).to eq 'hsm'
          expect(result['hsm']['partition']).to eq 'active_partition'
          expect(result['hsm']['partition-password']).to eq 'active_partpass'

          expect(result['encryption']['keys'].length).to eq 2

          first_key = result['encryption']['keys'][0]
          second_key = result['encryption']['keys'][1]

          expect(first_key['encryption-key-name']).to eq 'active_keyname'
          expect(first_key['provider-name']).to eq 'active_hsm'
          expect(first_key['active']).to eq true

          expect(second_key['encryption-key-name']).to eq 'another_keyname'
          expect(second_key['provider-name']).to eq 'active_hsm'
          expect(second_key.has_key?('active')).to eq false
        end
      end

      context 'dsm encryption' do
        let(:base_option_yaml) {
          <<-EOF
        properties:
          credhub:
            encryption:
              keys:
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

        it 'should set the dsm properties correctly' do
          options = {:context => manifest_properties.to_json}
          renderer = Bosh::Template::Renderer.new(options)
          result = YAML.load(renderer.render('../jobs/credhub/templates/application.yml.erb'))

          expect(result['encryption']['provider']).to eq 'dsm'

          expect(result['encryption']['keys'].length).to eq 2

          first_key = result['encryption']['keys'][0]
          second_key = result['encryption']['keys'][1]

          expect(first_key['encryption-key-name']).to eq 'active_keyname'
          expect(first_key['provider-name']).to eq 'active_dsm'
          expect(first_key['active']).to eq true

          expect(second_key['encryption-key-name']).to eq 'abcd1234abcd1234abcd1234abcd1234'
          expect(second_key['provider-name']).to eq 'active_dsm'
          expect(second_key.has_key?('active')).to eq false
        end
      end

      context 'dev_internal encryption' do
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
                  type: dev_internal
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

        context 'validating the dev_key' do
          it 'should be valid hexadecimal' do
            manifest_properties['properties']['credhub']['encryption']['keys'].first['dev_key'] = 'xyz'

            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error(ArgumentError, 'credhub.encryption.dev_key is not valid (must be 128 bit hexadecimal string).')
          end

          it 'should be 32 characters' do
            manifest_properties['properties']['credhub']['encryption']['keys'].first['dev_key'] = '3456abcd1234abcd1234abcd1234ab'

            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error(ArgumentError, 'credhub.encryption.dev_key is not valid (must be 128 bit hexadecimal string).')
          end

          it 'should not allow empty string' do
            manifest_properties['properties']['credhub']['encryption']['keys'].first['dev_key'] = ''

            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to raise_error(ArgumentError, 'credhub.encryption.dev_key is not valid (must be 128 bit hexadecimal string).')
          end

          it 'should allow the dev_key to be omitted' do
            manifest_properties['properties']['credhub']['encryption']['keys'].first.delete('dev_key')

            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)

            expect {
              renderer.render('../jobs/credhub/templates/application.yml.erb')
            }.to_not raise_error
          end
        end

        context 'when the user provides a dev key' do
          it 'sets the provider and dev key correctly' do
            manifest_properties['properties']['credhub']['encryption']['keys'].first['dev_key'] = '1234abcd1234abcd1234abcd1234abcd'
            options = {:context => manifest_properties.to_json}
            renderer = Bosh::Template::Renderer.new(options)
            result = YAML.load(renderer.render('../jobs/credhub/templates/application.yml.erb'))

            expect(result['encryption']['keys'].length).to eq 2

            first_key = result['encryption']['keys'].first
            second_key = result['encryption']['keys'].last

            expect(first_key['dev-key']).to eq '1234abcd1234abcd1234abcd1234abcd'
            expect(first_key['active']).to eq true

            expect(second_key['dev-key']).to eq '2345abcd1234abcd1234abcd1234abcd'
            expect(second_key.has_key?('active')).to eq false
          end
        end
      end
    end
  end
end
