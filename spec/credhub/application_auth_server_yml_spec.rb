require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/application/auth_server.yml template' do
    let(:template) { job.template('config/application/auth-server.yml') }
    let(:default_manifest) do
      {
        'credhub' => {
          'authentication' => {
            'uaa' => {
              'url' => 'some-uaa-url'
            }
          }
        }
      }
    end

    context 'default configuration' do
      it 'includes UAA auth server properties' do
        rendered_template = YAML.safe_load(template.render(default_manifest))

        expect(rendered_template['auth-server']).to eq(
          'url' => 'some-uaa-url',
          'trust_store' => '/var/vcap/jobs/credhub/config/trust_store.jks',
          'trust_store_password' => 'TRUST_STORE_PASSWORD_PLACEHOLDER'
        )

        expect(rendered_template['auth-server']['internal_url']).to be_nil
      end
    end

    context 'when UAA is disabled' do
      it 'does not include UAA auth server properties' do
        manifest = default_manifest.tap do |s|
          s['credhub']['authentication']['uaa'] = { 'enabled' => false }
        end
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['auth-server']).to be_nil
      end
    end

    context 'when a UAA internal URL is provided' do
      it 'sets the internal URL for UAA' do
        manifest = default_manifest.tap do |s|
          s['credhub']['authentication']['uaa']['internal_url'] = 'some-uaa-internal-url'
        end
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['auth-server']['internal_url']).to eq('some-uaa-internal-url')
      end
    end
  end
end
