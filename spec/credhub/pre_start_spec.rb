require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/pre-start template' do
    let(:template) { job.template('bin/pre-start') }

    context 'when both keys and providers are nested arrays' do
      it 'flattens them into two arrays' do
        manifest = {
          'credhub' => {
            'tls' => {
              'certificate' => 'some-certificate',
              'private_key' => 'some-key'
            },
            'encryption' => {
              'providers' => [
                [
                  {
                    'name' => 'some-internal-provider',
                    'type' => 'internal'
                  }
                ],
                []
              ],
              'keys' => [
                [
                  {
                    'provider_name' => 'some-internal-provider',
                    'key_properties' => 'some-properties',
                    'active' => true
                  }
                ],
                []
              ]
            }
          }
        }
        expect { template.render(manifest) }.not_to raise_error
      end
    end
  end
end
