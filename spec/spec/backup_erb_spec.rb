require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_backup_erb(dbtype="postgres", require_tls, tls_ca)
  option_yaml = <<-EOF
        properties:
          credhub:
            data_storage:
              username: example_username
              password: example_password
              host: 127.0.0.1
              port: 5432
              database: example_credhub
              require_tls: #{require_tls}
              tls_ca: #{tls_ca}
              type: #{dbtype}
  EOF

  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/backup.erb")
end

RSpec.describe "the template" do
  context "when db is postgres" do
    it "includes the pgdump command" do
      result = render_backup_erb(false, nil)
      expect(result).to include('export PGUTILS_DIR=/var/vcap/packages/pg_utils_9.4')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to_not include('export PGSSLMODE="verify-full"')
      expect(result).to_not include('export PGSSLROOTCERT=/var/vcap/jobs/credhub/config/database_ca.pem')
      expect(result).to include '"${PGUTILS_DIR}/bin/pg_dump" \\' + "\n" +
      '  --user="example_username" \\' + "\n" +
      '  --host="127.0.0.1" \\' + "\n" +
      '  --port="5432" \\' + "\n" +
      '  --format="custom" \\' + "\n" +
      '  "example_credhub" > "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
    end
    it "includes the pgdump command and require_tls is true" do
      result = render_backup_erb(true, "test_tls_ca")
      expect(result).to include('export PGUTILS_DIR=/var/vcap/packages/pg_utils_9.4')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to include('export PGSSLMODE="verify-full"')
      expect(result).to include('export PGSSLROOTCERT=/var/vcap/jobs/credhub/config/database_ca.pem')
      expect(result).to include '"${PGUTILS_DIR}/bin/pg_dump" \\' + "\n" +
                                    '  --user="example_username" \\' + "\n" +
                                    '  --host="127.0.0.1" \\' + "\n" +
                                    '  --port="5432" \\' + "\n" +
                                    '  --format="custom" \\' + "\n" +
                                    '  "example_credhub" > "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
    end
  end
  context "when db is not postgres" do
    it "logs that it skips this backup," do
      result = render_backup_erb("NOT_PG", nil, nil)
      expect(result).to_not include "/var/vcap/packages/pg_utils_9.4/bin/pg_dump \\\n"
      expect(result).to include 'Skipping backup, as database is not Postgres'
    end
  end
end
