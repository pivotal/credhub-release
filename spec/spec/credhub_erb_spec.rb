require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_credhub_template(require_tls, max_heap_size=1024, enable_bpm=false)
  option_yaml = <<-EOF
        properties:
          bpm:
            enabled: #{enable_bpm}
          credhub:
            max_heap_size: #{max_heap_size}
            data_storage:
              require_tls: #{require_tls}
  EOF

  # puts option_yaml
  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)

  renderer.render('../jobs/credhub/templates/credhub.erb')
end

describe 'credhub.erb template' do
  it 'sets the max heap size correctly' do
    template = render_credhub_template(false, max_heap_size=512)
    expect(template).to include('-Xmx${MAX_HEAP_SIZE}m')
  end

  context 'with credhub.data_storage.require_tls set to false' do
    it 'does not add java trust store properties' do
      template = render_credhub_template(false)
      expect(template).to_not include('-Djavax.net.ssl.trustStore')
      expect(template).to_not include('-Djavax.net.ssl.trustStorePassword')
    end

    it 'does not emit extra newlines in the java command' do
      template = render_credhub_template(false)
      expect(template).to_not match(/\\\n\s*\n/)
    end
  end

  context 'with credhub.data_storage.require_tls set to true' do
    it 'does add java trust store properties' do
      template = render_credhub_template(true)
      expect(template).to include('-Djavax.net.ssl.trustStore')
      expect(template).to include('-Djavax.net.ssl.trustStorePassword')
    end

    it 'does not emit extra newlines in the java command' do
      template = render_credhub_template(true)
      expect(template).to_not match(/\\\n\s*\n/)
    end
  end

  context 'with bpm.enabled set to true' do
    it 'adds jna.boot.library.path' do
      template = render_credhub_template(true,1024,  true)
      expect(template).to include('-Djna.boot.library.path=/var/vcap/packages/credhub')
    end
  end
end
