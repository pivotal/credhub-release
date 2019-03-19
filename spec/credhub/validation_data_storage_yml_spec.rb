require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/validation_data_storage.yml template' do
    let(:template) { job.template('config/validation_data_storage.yml') }

    it 'checks the type is valid' do
      manifest = {
        'credhub' => {
          'data_storage' => {
            'type' => 'bad-type'
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('credhub.data_storage.type must be set to "mysql", "postgres", or "in-memory".')
    end

    it 'checks that required key/value pairs exist when type is `mysql`' do
      manifest = {
        'credhub' => {
          'data_storage' => {
            'type' => 'mysql',
            'database' => '',
            'require_tls' => false
          }
        }
      }

      expect { template.render(manifest) }.to raise_error(
        'credhub.data_storage requires the following keys to be set when type is `mysql` or `postgres`: port, database, host, username, password'
      )
    end

    it 'checks that required key/value pairs exist when type is `postgres`' do
      manifest = {
        'credhub' => {
          'data_storage' => {
            'type' => 'postgres',
            'database' => '',
            'require_tls' => false
          }
        }
      }

      expect { template.render(manifest) }.to raise_error(
        'credhub.data_storage requires the following keys to be set when type is `mysql` or `postgres`: port, database, host, username, password'
      )
    end

    it 'checks that the tls_ca is set when tls is enabled' do
      manifest = {
        'credhub' => {
          'data_storage' => {
            'type' => 'mysql',
            'port' => 3306,
            'database' => 'some-database',
            'host' => 'some-host',
            'username' => 'some-username',
            'password' => 'some-password',
            'require_tls' => true
          }
        }
      }

      expect { template.render(manifest) }.to raise_error(
        'credhub.data_storage requires the tls_ca to be set when require_tls is set to true'
      )
    end

    it 'does not fail when host and port are not provided and link exists' do
      manifest = {
        'credhub' => {
          'data_storage' => {
            'type' => 'postgres',
            'database' => 'some-database',
            'username' => 'some-username',
            'password' => 'some-password',
            'require_tls' => false
          }
        }
      }

      links = [
        Bosh::Template::Test::Link.new(
          name: 'postgres',
          instances: [
            Bosh::Template::Test::LinkInstance.new(address: 'some-address')
          ],
          properties: {
            'databases' => { 'port' => 7777 }
          }
        )
      ]
      template.render(manifest, consumes: links)
    end
  end
end
