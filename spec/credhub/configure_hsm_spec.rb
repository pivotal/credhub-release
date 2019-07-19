require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/configure_hsm.sh template' do
    let(:template) { job.template('bin/configure_hsm.sh') }

    context 'when providers is a nested array' do
      it 'flattens providers arrays into one providers array' do
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
                [
                  {
                    'name' => 'kms-provider-1',
                    'type' => 'kms-plugin',
                    'connection_properties' => {
                      'endpoint' => '/path/to/first/socket'
                    }
                  }
                ]
              ]
            }
          }
        }
        expect { template.render(manifest) }.to_not raise_error
      end
    end
  end
end
