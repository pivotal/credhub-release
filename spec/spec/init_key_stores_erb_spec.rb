require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_template(ca_certs=nil)
  ca_certs_key = ca_certs ? "ca_certs: #{ca_certs}" : ''

  option_yaml = <<-EOF
        properties:
          credhub:
            authentication:
              uaa:
                #{ca_certs_key}
              mutual_tls:
                trusted_cas: []
            tls:
              certificate: fake-tls-certificate
              private_key: fake-tls-private_key
  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)

  renderer.render("../jobs/credhub/templates/init_key_stores.erb")
end

describe 'init_key_stores.erb template' do
  context 'with a ca_certs array containing a single cert' do
    it 'succeeds' do
      ca_certs = '[ FAKE-TEST-CA-CERT ]'
      expect { render_template(ca_certs) }.to_not raise_error
    end
  end

  context 'with a ca_certs array multiple certs' do
    it 'succeeds' do
      ca_certs = '[ FAKE-TEST-CA-CERT, ANOTHER-TEST-CA-CERT ]'
      expect { render_template(ca_certs) }.to_not raise_error
    end
  end

  context 'with no ca_certs key' do
    it 'raises an error' do
      expected_error = "At least one trusted CA certificate for UAA must be provided. Please add a value at 'credhub.authentication.uaa.ca_certs[]' and redeploy."

      expect { render_template() }.to raise_error(expected_error)
    end
  end

  context 'with an empty ca_certs array' do
    it 'raises an error' do
      expected_error = "At least one trusted CA certificate for UAA must be provided. Please add a value at 'credhub.authentication.uaa.ca_certs[]' and redeploy."

      expect { render_template('[]') }.to raise_error(expected_error)
    end
  end

  context 'with ca_certs containing a string instead of an array' do
    it 'raises an error' do
      expected_error = "At least one trusted CA certificate for UAA must be provided. Please add a value at 'credhub.authentication.uaa.ca_certs[]' and redeploy."

      expect { render_template('FAKE-TEST-CA-CERT') }.to raise_error(expected_error)
    end
  end
end
