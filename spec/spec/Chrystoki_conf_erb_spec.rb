require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'


def render(yaml)
  options = {:context => YAML.load(yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  renderer.render("../jobs/credhub/templates/Chrystoki.conf.erb")
end

RSpec.describe "the template" do
  context "with hsm" do
    it "renders" do
      result = render(<<-EOF
        properties:
          credhub:
            encryption:
              provider: hsm
              hsm:
                host: "example.com"
                port: 1792
      EOF
)
      expect(result).to include "ServerName00 = example.com"
      expect(result).to include "ServerPort00 = 1792"
    end
  end

  context "with dev_internal" do
    it "skips hsm setup" do
      result = render(<<-EOF
        properties:
          credhub:
            encryption:
              provider: dev_internal
      EOF
)
      expect(result).to_not be_nil
    end
  end
end
