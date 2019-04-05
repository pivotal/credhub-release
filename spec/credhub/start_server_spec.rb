require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/start_server template' do
    let(:template) { job.template('bin/start_server') }

    context 'when conjur backend is enabled' do
      it 'adds conjur to active profiles' do
        manifest = {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'internal_url' => 'some-url'
              }
            },
            'backends' => {
              'conjur' => {
                'enabled' => true
              }
            }
          }
        }

        rendered_template = template.render(manifest)

        expect(rendered_template).to include('-Dspring.profiles.active=prod,conjur')
      end
    end

    context 'when conjur backend is not enabled' do
      it 'does not add conjur to active profiles' do
        manifest = {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'internal_url' => 'some-url'
              }
            },
            'backends' => {
              'conjur' => {
                'enabled' => false
              }
            }
          }
        }

        rendered_template = template.render(manifest)

        expect(rendered_template).to_not include('-Dspring.profiles.active=prod,conjur')

      end
    end
  end
end

