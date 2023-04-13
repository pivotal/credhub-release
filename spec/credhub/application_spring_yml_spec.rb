require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  let(:postgres_link_instance) { Bosh::Template::Test::InstanceSpec.new(name: 'link_postgres_instance_name', address: 'some-postgres-host') }
  let(:postgres_link_properties) do
    {
      'databases' => { 'port' => 5432, 'address' => 'some-postgres-host' }
    }
  end
  let(:postgres_link) { Bosh::Template::Test::Link.new(name: 'postgres', instances: [postgres_link_instance], properties: postgres_link_properties) }

  describe 'config/application/spring.yml template' do
    let(:template) { job.template('config/application/spring.yml') }
    let(:default_in_memory_manifest) do
      {
        'credhub' => {
          'data_storage' => {
            'type' => 'in-memory'
          }
        }
      }
    end
    let(:default_mysql_manifest) do
      {
        'credhub' => {
          'data_storage' => {
            'type' => 'mysql',
            'port' => 3306,
            'database' => 'some-database',
            'host' => 'some-host',
            'username' => 'some-username',
            'password' => 'some-password'
          }
        }
      }
    end
    let(:default_postgres_manifest) do
      {
        'credhub' => {
          'data_storage' => {
            'type' => 'postgres',
            'database' => 'some-database',
            'username' => 'some-username',
            'password' => 'some-password'
          }
        }
      }
    end

    context 'default configuration' do
      it 'sets JPA properties' do
        rendered_template = YAML.safe_load(template.render(default_in_memory_manifest))

        expect(rendered_template['spring']['jpa']).to eq(
          'hibernate' => {
            'ddl_auto' => 'validate'
          }
        )
      end
    end

    context 'when the data storage type is in-memory' do
      it 'uses H2 migrations' do
        rendered_template = YAML.safe_load(template.render(default_in_memory_manifest))

        expect(rendered_template['spring']['flyway']['locations']).to eq([
                                                                           'classpath:/db/migration/common',
                                                                           'classpath:/db/migration/h2'
                                                                         ])
      end
    end

    context 'when the data storage type is mysql' do
      context 'default configuration' do
        it 'uses mysql properties and migrations with TLS enabled' do
          rendered_template = YAML.safe_load(template.render(default_mysql_manifest))

          expected_connection_url =
            'jdbc:mariadb://some-host:3306/some-database' \
            '?autoReconnect=true' \
            '&socketTimeout=3600000' \
            '&useSSL=true' \
            '&requireSSL=true' \
            '&verifyServerCertificate=true&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2' \
            '&trustCertificateKeyStorePassword=${TRUST_STORE_PASSWORD}' \
            '&trustCertificateKeyStoreUrl=/var/vcap/jobs/credhub/config/trust_store.jks'

          expect(rendered_template['spring']['datasource']).to eq(
            'username' => 'some-username',
            'password' => 'some-password',
            'url' => expected_connection_url
          )
          expect(rendered_template['spring']['flyway']['locations']).to eq([
                                                                             'classpath:/db/migration/common',
                                                                             'classpath:/db/migration/mysql'
                                                                           ])
        end
      end

      context 'when TLS is disabled' do
        it 'does not set the TLS params in the connection URL' do
          manifest = default_mysql_manifest.tap do |m|
            m['credhub']['data_storage']['require_tls'] = false
          end
          rendered_template = YAML.safe_load(template.render(manifest))

          expected_connection_url =
            'jdbc:mariadb://some-host:3306/some-database' \
            '?autoReconnect=true' \
            '&socketTimeout=3600000'

          expect(rendered_template['spring']['datasource']['url']).to eq(expected_connection_url)
        end
      end

      context 'when hostname verification is disabled' do
        it 'disables hostname verification in the connection URL' do
          manifest = default_mysql_manifest.tap do |m|
            m['credhub']['data_storage']['hostname_verification'] = { 'enabled' => false }
          end
          rendered_template = YAML.safe_load(template.render(manifest))

          expected_connection_url =
            'jdbc:mariadb://some-host:3306/some-database' \
            '?autoReconnect=true' \
            '&socketTimeout=3600000' \
            '&useSSL=true' \
            '&requireSSL=true' \
            '&verifyServerCertificate=true&enabledSslProtocolSuites=TLSv1,TLSv1.1,TLSv1.2' \
            '&trustCertificateKeyStorePassword=${TRUST_STORE_PASSWORD}' \
            '&trustCertificateKeyStoreUrl=/var/vcap/jobs/credhub/config/trust_store.jks' \
            '&disableSslHostnameVerification=true'

          expect(rendered_template['spring']['datasource']['url']).to eq(expected_connection_url)
        end
      end
    end

    context 'when the data storage type is postgres' do
      context 'default configuration' do
        it 'uses postgres properties and migrations with TLS enabled' do
          rendered_template = YAML.safe_load(template.render(default_postgres_manifest, consumes: [postgres_link]))

          expected_connection_url =
            'jdbc:postgresql://some-postgres-host:5432/some-database' \
            '?autoReconnect=true' \
            '&ssl=true' \
            '&sslmode=require'

          expect(rendered_template['spring']['datasource']).to eq(
            'username' => 'some-username',
            'password' => 'some-password',
            'url' => expected_connection_url
          )
          expect(rendered_template['spring']['flyway']['locations']).to eq([
                                                                             'classpath:/db/migration/common',
                                                                             'classpath:/db/migration/postgres'
                                                                           ])
        end

        it 'prefers postgres configuration properties over using properties from postgres link' do
          postgres_manifest = Marshal.load(Marshal.dump(default_postgres_manifest))
          postgres_manifest['credhub']['data_storage']['host'] = 'special-postgres-host'
          postgres_manifest['credhub']['data_storage']['port'] = 7777
          rendered_template = YAML.safe_load(template.render(postgres_manifest, consumes: [postgres_link]))

          expected_connection_url =
            'jdbc:postgresql://special-postgres-host:7777/some-database' \
            '?autoReconnect=true' \
            '&ssl=true' \
            '&sslmode=require'

          expect(rendered_template['spring']['datasource']).to eq(
            'username' => 'some-username',
            'password' => 'some-password',
            'url' => expected_connection_url
          )
          expect(rendered_template['spring']['flyway']['locations']).to eq([
                                                                             'classpath:/db/migration/common',
                                                                             'classpath:/db/migration/postgres'
                                                                           ])
        end

        it 'use postgres configuration properties when postgres link does not exist' do
          postgres_manifest = Marshal.load(Marshal.dump(default_postgres_manifest))
          postgres_manifest['credhub']['data_storage']['host'] = 'special-postgres-host'
          postgres_manifest['credhub']['data_storage']['port'] = 7777
          rendered_template = YAML.safe_load(template.render(postgres_manifest))

          expected_connection_url =
            'jdbc:postgresql://special-postgres-host:7777/some-database' \
            '?autoReconnect=true' \
            '&ssl=true' \
            '&sslmode=require'

          expect(rendered_template['spring']['datasource']).to eq(
            'username' => 'some-username',
            'password' => 'some-password',
            'url' => expected_connection_url
          )
          expect(rendered_template['spring']['flyway']['locations']).to eq([
                                                                             'classpath:/db/migration/common',
                                                                             'classpath:/db/migration/postgres'
                                                                           ])
        end
      end

      context 'when TLS is disabled' do
        it 'does not set the TLS params in the connection URL' do
          manifest = default_postgres_manifest.tap do |m|
            m['credhub']['data_storage']['require_tls'] = false
          end
          rendered_template = YAML.safe_load(template.render(manifest, consumes: [postgres_link]))

          expected_connection_url =
            'jdbc:postgresql://some-postgres-host:5432/some-database' \
            '?autoReconnect=true'

          expect(rendered_template['spring']['datasource']['url']).to eq(expected_connection_url)
        end
      end
      context 'when postgres is not configured correctly' do
        it 'should fail when postgres configuration properties do not include host and when postgres link does not exist' do
          postgres_manifest = Marshal.load(Marshal.dump(default_postgres_manifest))
          postgres_manifest['credhub']['data_storage'] = {
            'type' => 'postgres',
            'port' => 5432,
            'database' => 'some-database',
            'username' => 'some-username',
            'password' => 'some-password'
          }
          expect { template.render(postgres_manifest) }.to raise_error('postgres `host` must be set')
        end
      end
    end

    context 'when on the bootstrap instance' do
      it 'enables flyway' do
        instance = Bosh::Template::Test::InstanceSpec.new(bootstrap: true)
        rendered_template = YAML.safe_load(template.render(default_in_memory_manifest, spec: instance))

        expect(rendered_template['spring']['flyway']['enabled']).to eq(true)
      end
    end

    context 'when not on the bootstrap instance' do
      it 'disables flyway' do
        instance = Bosh::Template::Test::InstanceSpec.new(bootstrap: false)
        rendered_template = YAML.safe_load(template.render(default_in_memory_manifest, spec: instance))

        expect(rendered_template['spring']['flyway']['enabled']).to eq(false)
      end
    end
  end
end
