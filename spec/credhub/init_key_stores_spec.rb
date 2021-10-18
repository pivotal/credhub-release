require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/init_key_stores template' do
    let(:template) { job.template('bin/init_key_stores.sh') }

    context 'when a TLS certificate is provided' do
      let(:manifest) do
        {
          'credhub' => {
            'tls' => {
              'certificate' => 'my-tls-certificate',
              'private_key' => 'my-tls-private-key'
            },
            'authentication' => {
              'uaa' => {
                'ca_certs' => [
                  'my_first_uaa_cert'
                ]
              }
            }
          }
        }
      end

      it 'loads the TLS certificate' do

        script = template.render(manifest)
        expect(script).to include('openssl pkcs12 -export -in')
      end
    end
  end
end
