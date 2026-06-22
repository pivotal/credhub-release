require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/ctl template' do
    let(:template) { job.template('bin/ctl') }

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
      it 'does not add java.library.path for Luna' do
        script = template.render(base_manifest)
        expect(script).not_to include('luna-hsm-client')
      end
    end

    context 'when an HSM provider is configured' do
      it 'passes java.library.path for the Luna native library' do
        script = template.render(hsm_manifest)
        expect(script).to include('-Djava.library.path=/var/vcap/packages/luna-hsm-client-7.4/jsp/64')
      end
    end
  end
end
