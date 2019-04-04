require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/application/conjur.yml template' do
    let(:template) { job.template('config/application/conjur.yml') }

    context 'default configuration' do
      it 'does not enable conjur' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template).to eq(nil)
      end
    end

    context 'when conjur is enabled' do
      it 'uses the conjur properties' do
        manifest = {
          'credhub' => {
            'backends' => {
              'conjur' => {
                'enabled' => true,
                'base-url' => 'some-base-url',
                'base-policy' => 'some-base-policy',
                'account-name' => 'some-account-name',
                'user-name' => 'some-user-name',
                'api-key' => 'some-api-key'
              }
            }
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template).to eq(
          'conjur' => {
            'base-url' => 'some-base-url',
            'base-policy' => 'some-base-policy',
            'account-name' => 'some-account-name',
            'user-name' => 'some-user-name',
            'api-key' => 'some-api-key'
          }
        )
      end
    end
  end
end
