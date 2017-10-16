require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_pre_start_erb(data_storage_yaml, tls_yaml = '')
  option_yaml = <<-EOF
        properties:
          credhub:
            port: 8844
            encryption:
              keys:
                - provider_name: active_hsm
                  encryption_key_name: "active_keyname"
                  active: true
              providers:
                - name: active_hsm
                  type: hsm
                  servers:
                  - certificate: "hsm_cert1"
                  - certificate: "hsm_cert2"
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
  it "checks if credhub port is open" do
    result = render_pre_start_erb('{}', 'tls: {certificate: "foo", private_key: "bar"}')
    expect(result).to include "lsof -i :8844"
    expect(result).to include "fail_unless_credhub_port_is_open"
  end

  context "with hsm" do
    context "with TLS properties" do
      it "raises an error when either credhub.tls.certificate or credhub.tls.private_key is missing" do
        expect {render_pre_start_erb('{ }', 'tls: { certificate: "foo" }')}
            .to raise_error("credhub.tls.certificate and credhub.tls.private_key must both be set.")
        expect {render_pre_start_erb('{ }', 'tls: { certificate: "foo" }')}
            .to raise_error("credhub.tls.certificate and credhub.tls.private_key must both be set.")
        expect {render_pre_start_erb('{ }', 'tls: { }')}
            .to raise_error("credhub.tls.certificate and credhub.tls.private_key must both be set.")
        expect {render_pre_start_erb('{ }', '')}
            .to raise_error("credhub.tls.certificate and credhub.tls.private_key must both be set.")
      end
    end
  end

  context "with internal" do
    it "skips hsm setup" do
      option_yaml = <<-EOF
        properties:
          credhub:
            port: 8844
            encryption:
              keys:
                - provider_name: dev-key
                  active: true
                  encryption_password: test-encryption-password
              providers:
                - name: dev-key
                  type: internal
            tls:
              certificate: foo
              private_key: bar
      EOF

      options = {:context => YAML.load(option_yaml).to_json}
      renderer = Bosh::Template::Renderer.new(options)
      result = renderer.render("../jobs/credhub/templates/pre-start.erb")
      expect(result).to_not include "hsm_cert"
    end
  end
end
