require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'

def render_pre_start_erb(data_storage_yaml, tls_yaml = '')
  option_yaml = <<-EOF
        properties:
          credhub:
            hsm:
              certificate: "cert"
              client_certificate: "client_cert"
              client_key: "key"
            #{tls_yaml.empty? ? '' : tls_yaml}
            data_storage:
              #{data_storage_yaml}
  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/pre-start.erb")
end

RSpec.describe "the template" do
  context "with TLS properties" do
    it "does not add .pem files when either credhub.tls.certificate or credhub.tls.private_key is missing" do
      result = render_pre_start_erb('{ }', 'tls: { certificate: "foo" }')
      expect(result).not_to include "cat > $CERT_FILE <<EOL"
      result = render_pre_start_erb('{ }', 'tls: { private_key: "bar" }')
      expect(result).not_to include "cat > $CERT_FILE <<EOL"
    end

    it "adds .pem files when both credhub.tls.certificate and credhub.tls.private_key are set" do
      result = render_pre_start_erb('{ }', 'tls: { certificate: "foo", private_key: "bar" }')
      expect(result).to include "cat > $CERT_FILE <<EOL"
    end
  end

  context "with database storage properties" do
    it "does not create a DB client certificate file when credhub.data_storage.tls_ca is missing" do
      result = render_pre_start_erb('{ }', 'tls: { private_key: "bar" }')
      expect(result).not_to include "cat > $DATABASE_CA_CERT <<EOL"
    end

    it "creates a DB client certificate file when credhub.data_storage.tls_ca is set" do
      result = render_pre_start_erb('{ tls_ca: "my_tls_ca" }', 'tls: { certificate: "foo", private_key: "bar" }')
      expect(result).to include "cat > $DATABASE_CA_CERT <<EOL"
    end
  end
end
