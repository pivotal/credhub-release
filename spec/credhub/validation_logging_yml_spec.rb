require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/validation_logging.yml template' do
    let(:template) { job.template('config/validation_logging.yml') }

    it 'checks that the log_level is valid' do
      manifest = {
        'credhub' => {
          'log_level' => 'bad-log-level'
        }
      }

      expect do
        template.render(manifest)
      end.to raise_error('Invalid log_level. Valid types include: none, error, warn, info, or debug. Please update your manifest to proceed.')
    end
  end
end
