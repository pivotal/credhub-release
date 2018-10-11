require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'bosh-dns-aliases job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job('bbr-credhubdb') }

  describe 'bbr.json template' do
    let(:template) { job.template('config/bbr.json') }
    let(:default_data_storage) {
      {
        'type' => 'some-type',
        'username' => 'some-username',
        'password' => 'some-password',
        'host' => 'some-host',
        'port' => 'some-port',
        'database' => 'some-database',
        'require_tls' => true,
        'tls_ca' => 'some-ca'
      }
    }
    let(:other_data_storage) {
      {
        'type' => 'other-type',
        'username' => 'other-username',
        'password' => 'other-password',
        'host' => 'other-host',
        'port' => 'other-port',
        'database' => 'other-database',
        'require_tls' => true,
        'tls_ca' => 'other-ca'
      }
    }
    let(:data_storage_without_host) { default_data_storage.tap { |d| d.delete('host') } }
    let(:data_storage_without_tls) { default_data_storage.tap { |d| d['require_tls'] = false; d.delete('tls_ca') } }

    context 'when values are provided via `credhub.data_storage`' do
      it 'uses the values from `credhub.data_storage`' do
        spec = { 'credhub' => { 'data_storage' => default_data_storage } }
        rendered_template = template.render(spec)

        expect(JSON.parse(rendered_template)).to eq({
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'cert' => {
              'ca' => 'some-ca'
            }
          }
        })
      end

      context 'when a host is not provided' do
        context 'when the `database` link is present' do
          it 'uses the address of the `database` instance' do
            spec = { 'credhub' => { 'data_storage' => data_storage_without_host } }
            links = [
              Bosh::Template::Test::Link.new(
                name: 'database',
                instances: [
                  Bosh::Template::Test::LinkInstance.new(address: 'some-address'),
                  Bosh::Template::Test::LinkInstance.new(address: 'some-other-address')
                ]
              )
            ]
            rendered_template = template.render(spec, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq("some-address")
          end
        end

        context 'when it is provided via the `database` link' do
          it 'is not included in the config' do
            spec = { 'credhub' => { 'data_storage' => data_storage_without_host } }
            rendered_template = template.render(spec)

            expect(JSON.parse(rendered_template)['host']).to eq(nil)
          end
        end
      end

      context 'when TLS is disabled' do
        it 'does not include TLS in the config' do
          spec = { 'credhub' => { 'data_storage' => data_storage_without_tls } }
          rendered_template = template.render(spec)

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

        expect(JSON.parse(rendered_template)).to eq({
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'cert' => {
              'ca' => 'some-ca',
            },
          },
        })
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

            expect(JSON.parse(rendered_template)['host']).to eq("some-address")
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
        spec = { 'credhub' => { 'data_storage' => other_data_storage } }
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
        rendered_template = template.render(spec, consumes: links)

        expect(JSON.parse(rendered_template)).to eq({
          'username' => 'some-username',
          'password' => 'some-password',
          'port' => 'some-port',
          'database' => 'some-database',
          'adapter' => 'some-type',
          'host' => 'some-host',
          'tls' => {
            'cert' => {
              'ca' => 'some-ca'
            }
          }
        })
      end

      context 'when a host is not provided via the `credhub_db` link' do
        context 'when the `database` link is present' do
          it 'uses the address of the `database` instance' do
            spec = { 'credhub' => { 'data_storage' => other_data_storage } }
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
            rendered_template = template.render(spec, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq("some-address")
          end
        end

        context 'when it is not provided via the `database` link' do
          it 'is not included in the config' do
            spec = { 'credhub' => { 'data_storage' => other_data_storage } }
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
            rendered_template = template.render(spec, consumes: links)

            expect(JSON.parse(rendered_template)['host']).to eq(nil)
          end
        end
      end

      context 'when TLS is disabled via the `credhub_db` link' do
        it 'does not include TLS in the config' do
          spec = { 'credhub' => { 'data_storage' => other_data_storage } }
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
          rendered_template = template.render(spec, consumes: links)

          expect(JSON.parse(rendered_template)['tls']).to eq(nil)
        end
      end
    end
  end
end
