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
              },
              'mutual_tls' => {
                'trusted_cas' => []
              }
            }
          }
        }
      end

      it 'loads the TLS certificate' do
        script = template.render(manifest)
        expect(script).to include('openssl pkcs12 -export -in')
      end

      context 'when trusted CAs are provided' do
        it 'should import all provided CAs to the trust store' do
          concatenated_cas = '-----BEGIN CERTIFICATE-----
someCertBody1
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
someCertBody2
-----END CERTIFICATE-----
'
          another_ca = '-----BEGIN CERTIFICATE-----
someCertBody3
-----END CERTIFICATE-----
'
          manifest['credhub']['authentication']['mutual_tls']['trusted_cas'] = [concatenated_cas, another_ca]

          script = template.render(manifest)

          expect(script).to include('cat > ${MTLS_CA_CERT_FILE} <<EOL
-----BEGIN CERTIFICATE-----
someCertBody1
-----END CERTIFICATE-----
EOL')

          expect(script).to include('cat > ${MTLS_CA_CERT_FILE} <<EOL
-----BEGIN CERTIFICATE-----
someCertBody2
-----END CERTIFICATE-----
EOL')

          expect(script).to include('cat > ${MTLS_CA_CERT_FILE} <<EOL
-----BEGIN CERTIFICATE-----
someCertBody3
-----END CERTIFICATE-----
EOL')

          expect(script).to include('${JAVA_HOME}/bin/keytool -import -noprompt -trustcacerts   -keystore ${MTLS_TRUST_STORE_PATH}   -storepass ${MTLS_TRUST_STORE_PASSWORD}   -alias ${MTLS_CA_ALIAS}-0-0   -file ${MTLS_CA_CERT_FILE}')
          expect(script).to include('${JAVA_HOME}/bin/keytool -import -noprompt -trustcacerts   -keystore ${MTLS_TRUST_STORE_PATH}   -storepass ${MTLS_TRUST_STORE_PASSWORD}   -alias ${MTLS_CA_ALIAS}-0-1   -file ${MTLS_CA_CERT_FILE}')
          expect(script).to include('${JAVA_HOME}/bin/keytool -import -noprompt -trustcacerts   -keystore ${MTLS_TRUST_STORE_PATH}   -storepass ${MTLS_TRUST_STORE_PASSWORD}   -alias ${MTLS_CA_ALIAS}-1-0   -file ${MTLS_CA_CERT_FILE}')
        end
      end
    end
  end
end
