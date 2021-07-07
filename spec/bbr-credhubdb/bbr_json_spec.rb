require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'bbr-credhubdb job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('bbr-credhubdb') }

  describe 'bbr.json template' do
    let(:template) { job.template('config/bbr.json') }
    let(:default_data_storage) do
      {
        'type' => 'some-type',
        'username' => 'some-username',
        'password' => 'some-password',
        'host' => 'some-host',
        'port' => 'some-port',
        'database' => 'some-database',
        'require_tls' => true,
        'tls_ca' => 'some-ca',
        'hostname_verification' => {
            'enabled' => true
        }
      }
    end
    let(:other_data_storage) do
      {
        'type' => 'other-type',
        'username' => 'other-username',
        'password' => 'other-password',
        'host' => 'other-host',
        'port' => 'other-port',
        'database' => 'other-database',
        'require_tls' => true,
        'tls_ca' => 'other-ca',
        'hostname_verification' => {
            'enabled' => true
        }
      }
    end
    let(:data_storage_without_host) { default_data_storage.tap { |d| d.delete('host') } }
    let(:data_storage_without_port) { default_data_storage.tap { |d| d.delete('port') } }
    let(:data_storage_without_tls) do
      default_data_storage.tap do |d|
        d['require_tls'] = false
        d.delete('tls_ca')
      end
    end

    context 'when values are provided via `credhub.data_storage`' do
      it 'uses the values from `credhub.data_storage`' do
        manifest = { 'credhub' => { 'data_storage' => default_data_storage } }
        rendered_template = template.render(manifest)

        expect(JSON.parse(rendered_template)).to eq(
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'skip_host_verify' => false,
            'cert' => {
              'ca' => 'some-ca'
            }
          }
        )
      end

      context 'port' do
        context 'when the `database` link is present' do
          it 'uses the port of the `database` link' do
            manifest = { 'credhub' => { 'data_storage' => data_storage_without_port } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address')
                ],
                properties: {
                  'databases' => { 'port' => 7777 }
                }
              )
            ]
            rendered_template = template.render(manifest, consumes: links)

            expect(JSON.parse(rendered_template)['port']).to eq(7777)
          end
        end

        context 'when the `database` link and the config are present' do
          it 'uses the config' do
            manifest = { 'credhub' => { 'data_storage' => default_data_storage } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address')
                ],
                properties: {
                  'databases' => { 'port' => 7777 }
                }
              )
            ]
            rendered_template = template.render(manifest, consumes: links)

            expect(JSON.parse(rendered_template)['port']).to eq('some-port')
          end
        end
      end

      context 'when a host is not provided' do
        context 'when the `database` link is present' do
          it 'uses the address of the `database` instance' do
            manifest = { 'credhub' => { 'data_storage' => data_storage_without_host } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address'),
                  Bosh::Template::Test::LinkInstance.new(address: 'some-other-address')
                ]
              )
            ]
            rendered_template = template.render(manifest, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq('some-address')
          end
        end

        context 'when it is provided via the `database` link' do
          it 'is not included in the config' do
            manifest = { 'credhub' => { 'data_storage' => data_storage_without_host } }
            rendered_template = template.render(manifest)

            expect(JSON.parse(rendered_template)['host']).to eq(nil)
          end
        end
      end

      context 'when TLS is disabled' do
        it 'does not include TLS in the config' do
          manifest = { 'credhub' => { 'data_storage' => data_storage_without_tls } }
          rendered_template = template.render(manifest)

          expect(JSON.parse(rendered_template)['tls']).to eq(nil)
        end
      end
    end

    context 'when values are provided via the `credhub_db` link' do
      it 'uses the values from the `credhub_db` link' do
        links = [
          Bosh::Template::Test::Link.new(
            name: 'credhub_db',
            instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
            properties: {
              'credhub' => {
                'data_storage' => default_data_storage
              }
            }
          )
        ]
        rendered_template = template.render(nil, consumes: links)

        expect(JSON.parse(rendered_template)).to eq(
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'skip_host_verify' => false,
            'cert' => {
              'ca' => 'some-ca'
            }
          }
        )
      end

      context 'when a host is not provided' do
        context 'when the `database` link is present' do
          it 'uses the address of the `database` instance' do
            links = [
              Bosh::Template::Test::Link.new(
                name: 'credhub_db',
                instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
                properties: {
                  'credhub' => {
                    'data_storage' => data_storage_without_host
                  }
                }
              ),
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address'),
                  Bosh::Template::Test::LinkInstance.new(address: 'some-other-address')
                ]
              )
            ]
            rendered_template = template.render(nil, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq('some-address')
          end
        end

        context 'when it is provided via the `database` link' do
          it 'is not included in the config' do
            links = [
              Bosh::Template::Test::Link.new(
                name: 'credhub_db',
                instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
                properties: {
                  'credhub' => {
                    'data_storage' => data_storage_without_host
                  }
                }
              )
            ]
            rendered_template = template.render(nil, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq(nil)
          end
        end
      end

      context 'when TLS is disabled' do
        it 'does not include TLS in the config' do
          links = [
            Bosh::Template::Test::Link.new(
              name: 'credhub_db',
              instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
              properties: {
                'credhub' => {
                  'data_storage' => data_storage_without_tls
                }
              }
            )
          ]
          rendered_template = template.render(nil, consumes: links)

          expect(JSON.parse(rendered_template)['tls']).to eq(nil)
        end
      end
    end

    context 'when values are provided via both `credhub.data_storage` and the `credhub_db` link' do
      it 'uses the values from the `credhub_db` link' do
        manifest = { 'credhub' => { 'data_storage' => other_data_storage } }
        links = [
          Bosh::Template::Test::Link.new(
            name: 'credhub_db',
            instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
            properties: {
              'credhub' => {
                'data_storage' => default_data_storage
              }
            }
          )
        ]
        rendered_template = template.render(manifest, consumes: links)

        expect(JSON.parse(rendered_template)).to eq(
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'skip_host_verify' => false,
            'cert' => {
              'ca' => 'some-ca'
            }
          }
        )
      end

      context 'when a host is not provided via the `credhub_db` link' do
        context 'when the `database` link is present' do
          it 'uses the address of the `database` instance' do
            manifest = { 'credhub' => { 'data_storage' => other_data_storage } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'credhub_db',
                instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
                properties: {
                  'credhub' => {
                    'data_storage' => data_storage_without_host
                  }
                }
              ),
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address'),
                  Bosh::Template::Test::LinkInstance.new(address: 'some-other-address')
                ]
              )
            ]
            rendered_template = template.render(manifest, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq('some-address')
          end
        end

        context 'when it is not provided via the `database` link' do
          it 'is not included in the config' do
            manifest = { 'credhub' => { 'data_storage' => other_data_storage } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'credhub_db',
                instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
                properties: {
                  'credhub' => {
                    'data_storage' => data_storage_without_host
                  }
                }
              )
            ]
            rendered_template = template.render(manifest, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq(nil)
          end
        end
      end

      context 'when TLS is disabled via the `credhub_db` link' do
        it 'does not include TLS in the config' do
          manifest = { 'credhub' => { 'data_storage' => other_data_storage } }
          links = [
            Bosh::Template::Test::Link.new(
              name: 'credhub_db',
              instances: [Bosh::Template::Test::LinkInstance.new(address: 'some-address')],
              properties: {
                'credhub' => {
                  'data_storage' => data_storage_without_tls
                }
              }
            )
          ]
          rendered_template = template.render(manifest, consumes: links)

          expect(JSON.parse(rendered_template)['tls']).to eq(nil)
        end
      end
    end
  end
end
