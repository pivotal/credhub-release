require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/validation_authorization.yml template' do
    let(:template) { job.template('config/validation_authorization.yml') }

    it 'checks that there are permissions provided when acls are enabled' do
      manifest = {
        'credhub' => {
          'authorization' => {
            'acls' => {
              'enabled' => true
            }
          }
        }
      }

      expect do
        template.render(manifest)
      end.to raise_error('When ACLs are enabled you must provide at least one permission so that some actor can access CredHub. Please update your manifest to proceed.')
    end
  end
end
