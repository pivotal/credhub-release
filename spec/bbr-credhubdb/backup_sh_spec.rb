require 'rspec'
require 'yaml'
require 'bosh/template/test'

describe 'bbr-credhubdb job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('bbr-credhubdb') }

  describe 'backup.sh template' do
    let(:template) { job.template('bin/bbr/backup') }

    context 'when release_level_backup is set to false' do
      it 'prints message that script was deactivated' do
        manifest = { 'release_level_backup' => false }
        rendered_template = template.render(manifest)

        expect(rendered_template).to include('script deactivated due to release_level_backup being set to FALSE')
      end
    end

    context 'when release_level_backup is set to true' do
      context 'when credhub_db does not exist' do
        it 'prints message that script was deactivated' do
          manifest = { 'release_level_backup' => true }
          rendered_template = template.render(manifest)

          expect(rendered_template).to include('script deactivated due to release_level_backup being set to FALSE')
        end
      end
      context 'when credhub_db exists' do
        it 'creates backup.sh script' do
          manifest = { 'release_level_backup' => true }
          links = [
            Bosh::Template::Test::Link.new(
              name: 'credhub_db',
              instances: [
                Bosh::Template::Test::LinkInstance.new(address: 'some-address')
              ]
            )
          ]
          rendered_template = template.render(manifest, consumes: links)

          expect(rendered_template).to include('JOB_PATH=')
        end
      end
    end
  end
end
