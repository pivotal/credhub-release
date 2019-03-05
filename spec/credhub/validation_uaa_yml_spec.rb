require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/validation_uaa.yml template' do
    let(:template) { job.template('config/validation_uaa.yml') }

    it 'checks that there is a url and ca certs when uaa is enabled' do
      manifest = {
        'credhub' => {
          'authentication' => {
            'uaa' => {
              'enabled' => true
            }
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('When UAA is enabled you must provide a URL and CA Certs. Please update your manifest to proceed.')
    end
  end
end
