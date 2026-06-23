require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/credhub template' do
    let(:template) { job.template('bin/credhub') }

    let(:base_manifest) do
      {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'name' => 'some-internal-provider',
                'type' => 'internal'
              }
            ]
          }
        }
      }
    end

    let(:hsm_manifest) do
      {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'name' => 'primary',
                'type' => 'hsm',
                'connection_properties' => {
                  'partition' => 'some-partition',
                  'partition_password' => 'some-partition-password',
                  'client_certificate' => 'some-client-certificate',
                  'client_key' => 'some-client-key',
                  'servers' => [
                    {
                      'host' => '10.0.0.1',
                      'port' => 1792,
                      'certificate' => 'some-hsm-certificate',
                      'partition_serial_number' => '123456789'
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    end

    context 'when no HSM provider is configured' do
      it 'does not reference luna-hsm-client' do
        script = template.render(base_manifest)
        expect(script).not_to include('luna-hsm-client')
      end

      it 'launches via JarLauncher without a Luna classpath entry' do
        script = template.render(base_manifest)
        expect(script).to include('org.springframework.boot.loader.launch.JarLauncher')
        expect(script).to include('LUNA_CP=""')
      end
    end

    context 'when an HSM provider is configured' do
      it 'sets java.library.path to the Luna native library directory' do
        script = template.render(hsm_manifest)
        expect(script).to include('-Djava.library.path=/var/vcap/packages/luna-hsm-client-7.4/jsp/64')
      end

      it 'adds LunaProvider.jar to the classpath via -cp' do
        script = template.render(hsm_manifest)
        expect(script).to include('LunaProvider.jar')
        expect(script).to include('org.springframework.boot.loader.launch.JarLauncher')
      end
    end

    context 'when providers is a nested array containing an HSM provider' do
      it 'sets java.library.path and adds LunaProvider.jar to the classpath' do
        manifest = {
          'credhub' => {
            'encryption' => {
              'providers' => [
                [
                  {
                    'name' => 'primary',
                    'type' => 'hsm',
                    'connection_properties' => {
                      'partition' => 'p',
                      'partition_password' => 'pw',
                      'client_certificate' => 'cert',
                      'client_key' => 'key',
                      'servers' => [
                        {
                          'host' => '10.0.0.1',
                          'port' => 1792,
                          'certificate' => 'hsm-cert',
                          'partition_serial_number' => '123'
                        }
                      ]
                    }
                  }
                ]
              ]
            }
          }
        }
        script = template.render(manifest)
        expect(script).to include('-Djava.library.path=/var/vcap/packages/luna-hsm-client-7.4/jsp/64')
        expect(script).to include('LunaProvider.jar')
      end
    end
  end
end
