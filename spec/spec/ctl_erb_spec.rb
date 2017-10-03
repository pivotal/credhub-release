require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_ctl_template(require_tls, max_heap_size=1024)
  option_yaml = <<-EOF
        properties:
          credhub:
            max_heap_size: #{max_heap_size}
            data_storage:
              require_tls: #{require_tls}
  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)

  renderer.render('../jobs/credhub/templates/ctl.erb')
end

describe 'ctl.erb template' do
  it 'sets the max heap size correctly' do
    template = render_ctl_template(false, max_heap_size=512)
    expect(template).to include('export MAX_HEAP_SIZE=512')
  end
end
