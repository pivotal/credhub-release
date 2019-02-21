require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job('credhub') }

  describe 'bpm.yml template' do
    let(:template) { job.template('config/bpm.yml') }

    context 'when credhub.encryption.providers contains kms-plugin providers' do
      it 'mounts the socket directory as additional volumes' do
        encryption_providers = [
          {
            'name' => 'internal',
            'type' => 'internal-provider'
          },
          {
            'name' => 'kms-provider-1',
            'type' => 'kms-plugin',
            'connection_properties' => {
              'endpoint' => '/path/to/first/socket'
            }
          },
          {
            'name' => 'kms-provider-2',
            'type' => 'kms-plugin',
            'connection_properties' => {
              'endpoint' => '/path/to/second/socket'
            }
          }
        ]
        spec = { 'credhub' => { 'encryption' => {'providers' => encryption_providers } } }
        rendered_template = template.render(spec)

        additional_volumes = YAML.load(rendered_template)['processes'][0]['additional_volumes']
        expect(additional_volumes).to include(
          {
            'path' => '/path/to/first',
            'writable' => true,
            'allow_executions' => true
          },
          {
            'path' => '/path/to/second',
            'writable' => true,
            'allow_executions' => true
          }
        )
      end
    end
  end
end
