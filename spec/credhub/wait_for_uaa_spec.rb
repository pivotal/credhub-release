require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/wait_for_uaa template' do
    let(:template) { job.template('bin/wait_for_uaa') }

    context 'when uaa is enabled' do
      let(:manifest) do
        {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'enabled' => true
              }
            }
          }
        }
      end

      context 'when uaa.internal_url is specified' do
        it 'waits for uaa to be available on internal_url' do
          manifest['credhub']['authentication']['uaa']['internal_url'] = 'some-internal-url'

          expect(template.render(manifest)).to include('some-internal-url')
        end
      end

      context 'when uaa.internal_url is not specified' do
        it 'waits for uaa to be available on internal_url' do
          manifest['credhub']['authentication']['uaa']['url'] = 'some-url'

          expect(template.render(manifest)).to include('some-url')
        end
      end

      context 'when wait_for_start is not specified' do
        it 'waits for uaa to be available' do
          manifest['credhub']['authentication']['uaa']['internal_url'] = 'some-internal-url'

          expect(template.render(manifest)).to include('Successfully connected to UAA, continuing startup')
        end
      end

      context 'when wait_for_start is specified to be false' do
        it 'does not wait for uaa to be available' do
          manifest['credhub']['authentication']['uaa']['internal_url'] = 'some-internal-url'
          manifest['credhub']['authentication']['uaa']['wait_for_start'] = false

          expect(template.render(manifest)).to include('Not waiting for UAA to start')
          expect(template.render(manifest)).to_not include('curl')
        end
      end
    end

    context 'when uaa is disabled' do
      let(:manifest) do
        {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'enabled' => false
              }
            }
          }
        }
      end

      it 'does nothing' do
        expect(template.render(manifest)).to include('UAA is not enabled')
        expect(template.render(manifest)).to_not include('curl')
      end
    end
  end
end
