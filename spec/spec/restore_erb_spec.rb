require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_restore_erb(dbtype="postgres")
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
  return renderer.render("../jobs/credhub/templates/restore.erb")
end

RSpec.describe "the template" do
  context "when db is postgres" do
    it "includes the pgrestore command" do
      result = render_restore_erb()
      expect(result).to include('source /var/vcap/jobs/postgres/bin/pgconfig.sh')
      expect(result).to include('export PG_PKG_DIR="${PACKAGE_DIR}"')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to include "${PG_PKG_DIR}/bin/pg_restore \\\n" +
      '  --user="example_username" \\' + "\n" +
      '  --host="127.0.0.1" \\' + "\n" +
      '  --port="5432" \\' + "\n" +
      '  --format="custom" \\' + "\n" +
      '  --schema="public" \\' + "\n" +
      '  --clean \\' + "\n" +
      '  --dbname="example_credhub" "$BBR_ARTIFACT_DIRECTORY"/credhubdb_dump'
    end
  end
  context "when db is not postgres" do
    it "logs that it skips this restore," do
      result = render_restore_erb("NOT_PG")
      expect(result).to_not include "${PG_PKG_DIR}/bin/pg_dump \\\n"
      expect(result).to include 'Skipping restore, as database is not Postgres'
    end
  end
end
