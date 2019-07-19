require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/encryption.conf template' do
    let(:template) { job.template('config/encryption.conf') }

    context 'when both keys and providers are nested arrays' do
      it 'flattens them into two arrays' do
        manifest = {
          'credhub' => {
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
        expect { template.render(manifest) }.to_not raise_error
      end
    end
  end
end
