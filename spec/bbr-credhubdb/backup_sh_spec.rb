require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'bbr-credhubdb job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('bbr-credhubdb') }

  let(:credhub_db_link_instance) { Bosh::Template::Test::InstanceSpec.new(name: 'link_credhub_db_instance_name', address: 'some-postgres-host') }
  let(:credhub_db_link_properties) do
    {
      'some-key' => 'some-value'
    }
  end
  let(:credhub_db_link) { Bosh::Template::Test::Link.new(name: 'credhub_db', instances: [credhub_db_link_instance], properties: credhub_db_link_properties) }
  let(:empty_credhub_db_link) { Bosh::Template::Test::Link.new(name: 'credhub_db', instances: [], properties: credhub_db_link_properties) }

  describe 'bbr.json template' do
    let(:template) { job.template('bin/bbr/backup') }
    let(:backup_template) do
      {
        'release_level_backup' => true
      }
    end

    context 'rendering the template' do
      it 'does not create the script if there is no credhub_db link' do
        rendered_template = template.render(backup_template)

        expect(rendered_template).to include('deactivated')
      end

      it 'does not create the script if credhub_db link exists with instance count equal to 0' do
        rendered_template = template.render(backup_template, consumes: [empty_credhub_db_link])

        expect(rendered_template).to include('deactivated')
      end

      it 'creates the script if credhub_db link exists with instance count is greater than 0' do
        rendered_template = template.render(backup_template, consumes: [credhub_db_link])

        expect(rendered_template).to_not include('deactivated')
      end
    end
  end
end
