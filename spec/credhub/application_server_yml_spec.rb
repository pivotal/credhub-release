require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/application/server.yml template' do
    let(:template) { job.template('config/application/server.yml') }

    context 'default configuration' do
      it 'uses port 8844' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['server']['port']).to eq(8844)
      end

      it 'enables SSL with a key store' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['server']['ssl']['enabled']).to eq(true)
        expect(rendered_template['server']['ssl']['enabled_protocols']).to eq('TLSv1.2')
        expect(rendered_template['server']['ssl']['key_store']).to eq('/var/vcap/jobs/credhub/config/cacerts.jks')
        expect(rendered_template['server']['ssl']['key_password']).to eq('KEY_STORE_PASSWORD_PLACEHOLDER')
        expect(rendered_template['server']['ssl']['key_store_password']).to eq('KEY_STORE_PASSWORD_PLACEHOLDER')
        expect(rendered_template['server']['ssl']['key_alias']).to eq('credhub_tls_cert')
      end

      it 'uses default ciphers in the correct order' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        ciphers = rendered_template['server']['ssl']['ciphers'].split(',')
        expect(ciphers).to eq(%w[
                                TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
                                TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
                                TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                                TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                              ])
      end

      it 'does not include client trust store properties' do
        manifest = { 'credhub' => {} }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['server']['ssl']['client_auth']).to be_nil
        expect(rendered_template['server']['ssl']['trust_store']).to be_nil
        expect(rendered_template['server']['ssl']['trust_store_password']).to be_nil
        expect(rendered_template['server']['ssl']['trust_store_type']).to be_nil
      end
    end

    context 'when a port is provided' do
      it 'uses the port' do
        port = rand(1..65_525)
        manifest = {
          'credhub' => {
            'port' => port
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['server']['port']).to eq(port)
      end
    end

    # CredHubDeprecatedStartingAfter(2.1.2)
    context 'when Java 7 chipers are enabled' do
      it 'appends Java 7 ciphers' do
        manifest = {
          'credhub' => {
            'java7_tls_ciphers_enabled' => true
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        ciphers = rendered_template['server']['ssl']['ciphers'].split(',')
        expect(ciphers).to eq(%w[
                                TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
                                TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
                                TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                                TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                                TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
                                TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
                              ])
      end
    end

    context 'when mutual TLS CAs are provided' do
      it 'includes client trust store properties' do
        manifest = {
          'credhub' => {
            'authentication' => {
              'mutual_tls' => {
                'trusted_cas' => ['some-trusted-ca']
              }
            }
          }
        }
        rendered_template = YAML.safe_load(template.render(manifest))

        expect(rendered_template['server']['ssl']['client_auth']).to eq('want')
        expect(rendered_template['server']['ssl']['trust_store']).to eq('/var/vcap/jobs/credhub/config/mtls_trust_store.jks')
        expect(rendered_template['server']['ssl']['trust_store_password']).to eq('MTLS_TRUST_STORE_PASSWORD_PLACEHOLDER')
        expect(rendered_template['server']['ssl']['trust_store_type']).to eq('JKS')
      end
    end
  end
end
