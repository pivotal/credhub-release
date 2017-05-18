require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_backup_erb(dbtype="postgres")
  option_yaml = <<-EOF
        properties:
          credhub:
            data_storage:
              username: example_username
              password: example_password
              host: 127.0.0.1
              port: 5432
              database: example_credhub
              type: #{dbtype}
  EOF

  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/backup.erb")
end

RSpec.describe "the template" do
  context "when db is postgres" do
    it "includes the pgdump command" do
      result = render_backup_erb()
      expect(result).to include('export PG_PKG_DIR=/var/vcap/packages/postgres-9.4')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to include "${PG_PKG_DIR}/bin/pg_dump \\\n" +
      '  --user="example_username" \\' + "\n" +
      '  --host="127.0.0.1" \\' + "\n" +
      '  --port="5432" \\' + "\n" +
      '  --format="custom" \\' + "\n" +
      '  "example_credhub" > "$BBR_ARTIFACT_DIRECTORY"/credhubdb_dump'
    end
  end
  context "when db is not postgres" do
    it "logs that it skips this backup," do
      result = render_backup_erb("NOT_PG")
      expect(result).to_not include "/var/vcap/packages/postgres-${PGVERSION}/bin/pg_dump \\\n"
      expect(result).to include 'Skipping backup, as database is not Postgres'
    end
  end
end
