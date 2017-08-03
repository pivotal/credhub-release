require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_database_ca_pem_erb(tls_block)
  option_yaml = <<-EOF
        properties:
          credhub:
            data_storage: #{tls_block}
  EOF

  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/database_ca.pem.erb")
end

RSpec.describe "the template" do
  context "when require_tls is true and tls_ca is provided" do
    it "renders tls_ca to a file" do
      result = render_database_ca_pem_erb('{ require_tls: true, tls_ca: "test_tls_ca" }')
      expect(result).to include('test_tls_ca')
    end
  end

  context "when require_tls is true and no tls_ca is provided" do
    it "raises an error" do
      expect {render_database_ca_pem_erb('{ require_tls: true }')}
          .to raise_error("A CA must be provided at 'credhub.data_storage.tls_ca' if database TLS is required. Please add a CA or disable TLS and redeploy.")
    end
  end

  context "when require_tls is false" do
    it "renders an empty file" do
      result = render_database_ca_pem_erb('{ require_tls: false }')
      expect(result.strip).to be_empty
    end
  end
end
