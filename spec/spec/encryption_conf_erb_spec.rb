require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'


def render(yaml)
  options = {:context => YAML.load(yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  renderer.render("../jobs/credhub/templates/encryption.conf.erb")
end

RSpec.describe "the encryption config template" do
  context "with hsm" do
    it "renders the Chrystoki config" do
      result = render(<<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: hsm-provider
                  encryption_key_name: test-key
                  active: true
              providers:
                - name: hsm-provider
                  type: hsm
                  servers:
                  - host: "example.com"
                    port: 1792
      EOF
)
      expect(result).to include "ServerName00 = example.com"
      expect(result).to include "ServerPort00 = 1792"
    end

    it "renders multiple servers in the Chrystoki config" do
      result = render(<<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: hsm-provider
                  encryption_key_name: test-key
                  active: true
              providers:
                - name: hsm-provider
                  type: hsm
                  servers:
                  - host: "server1.com"
                    port: 1792
                  - host: "server2.com"
                    port: 1792
      EOF
      )
      expect(result).to include "ServerName00 = server1.com"
      expect(result).to include "ServerPort00 = 1792"
      expect(result).to include "ServerName01 = server2.com"
      expect(result).to include "ServerPort01 = 1792"
    end

    it "supplies a default port" do
      result = render(<<-EOF
        properties:
          credhub:
            encryption:
              keys:
                - provider_name: hsm-provider
                  encryption_key_name: test-key
                  active: true
              providers:
                - name: hsm-provider
                  type: hsm
                  servers:
                  - host: "example.com"
      EOF
)
      expect(result).to include "ServerName00 = example.com"
      expect(result).to include "ServerPort00 = 1792"
    end
  end
end
