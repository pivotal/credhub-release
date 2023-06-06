require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/application/security.yml template' do
    let(:template) { job.template('config/application/security.yml') }

    context 'default configuration' do
      it 'enables ACLs' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['security']['authorization']['acls']['enabled']).to eq(true)
      end
      it 'enables oauth' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['security']['oauth2']['enabled']).to eq(true)
      end
      it 'has empty permissions' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['security']['authorization']['permissions']).to eq([])
      end
    end

    context 'when permissions are specified' do
      it 'uses the permissions' do
        manifest = {
          'credhub' => {
            'authorization' => {
              'permissions' => [
                {
                  'path' => 'some-path',
                  'actors' => ['some-actor'],
                  'operations' => ['some-operation']
                },
                {
                  'path' => 'some-other-path',
                  'actors' => %w[some-actor some-other-actor],
                  'operations' => %w[some-operation some-other-operation]
                }
              ]
            }
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expected_rendered_template = [
          {
            'path' => 'some-path',
            'actors' => ['some-actor'],
            'operations' => ['some-operation']
          },
          {
            'path' => 'some-other-path',
            'actors' => %w[some-actor some-other-actor],
            'operations' => %w[some-operation some-other-operation]
          }
        ]

        expect(rendered_template['security']['authorization']['permissions']).to eq(expected_rendered_template)
      end
    end

    context 'when ACLs are specified' do
      it 'does not use ACLs when they are disabled' do
        manifest = {
          'credhub' => {
            'authorization' => {
              'acls' => {
                'enabled' => false
              }
            }
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['security']['authorization']['acls']['enabled']).to eq(false)
      end
    end

    context 'when oauth is disabled' do
      it 'disables oauth' do
        manifest = {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'enabled' => false
              }
            }
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['security']['oauth2']['enabled']).to eq(false)
      end
    end
  end
end
