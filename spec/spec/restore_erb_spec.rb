require 'erb'
require 'template'
require 'bosh/template/renderer'
require 'yaml'
require 'json'
require 'fileutils'

def render_restore_erb(dbtype, require_tls, is_bootstrap=true)
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
              type: #{dbtype}
        bootstrap: #{is_bootstrap}
  EOF

  options = {:context => YAML.load(option_yaml).to_json}
  renderer = Bosh::Template::Renderer.new(options)
  return renderer.render("../jobs/credhub/templates/restore.erb")
end

RSpec.describe "the template" do
  context "when db is postgres" do
    it "includes the pgrestore command with require_tls:false" do
      result = render_restore_erb("postgres", false)
      expect(result).to include('export PGUTILS_DIR=/var/vcap/packages/database-backup-restorer-postgres')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to_not include('export PGSSLMODE="verify-full"')
      expect(result).to_not include('export PGSSLROOTCERT=/var/vcap/jobs/credhub/config/database_ca.pem')
      expect(result).to include '"${PGUTILS_DIR}/bin/pg_restore" \\' + "\n" +
                                    '  --user="example_username" \\' + "\n" +
                                    '  --host="127.0.0.1" \\' + "\n" +
                                    '  --port="5432" \\' + "\n" +
                                    '  --format="custom" \\' + "\n" +
                                    '  --schema="public" \\' + "\n" +
                                    '  --clean \\' + "\n" +
                                    '  --dbname="example_credhub" "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
    end
    it "includes the pgrestore command with ssl properties when require_tls:true" do
      result = render_restore_erb("postgres", true)
      expect(result).to include('export PGUTILS_DIR=/var/vcap/packages/database-backup-restorer-postgres')
      expect(result).to include('export PGPASSWORD="example_password"')
      expect(result).to include('export PGSSLMODE="verify-full"')
      expect(result).to include('export PGSSLROOTCERT=/var/vcap/jobs/credhub/config/database_ca.pem')
      expect(result).to include '"${PGUTILS_DIR}/bin/pg_restore" \\' + "\n" +
                                    '  --user="example_username" \\' + "\n" +
                                    '  --host="127.0.0.1" \\' + "\n" +
                                    '  --port="5432" \\' + "\n" +
                                    '  --format="custom" \\' + "\n" +
                                    '  --schema="public" \\' + "\n" +
                                    '  --clean \\' + "\n" +
                                    '  --dbname="example_credhub" "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
    end
  end

  context "when db is mysql" do
    it "includes the mysql command with require_tls:false" do
      result = render_restore_erb("mysql", false)
      expect(result).to include 'export MYSQLUTILS_DIR=/var/vcap/packages/database-backup-restorer-mysql'
      expect(result).to include '"${MYSQLUTILS_DIR}/bin/mysql" \\'
      expect(result).to include '-u "example_username" \\'
      expect(result).to include '-h "127.0.0.1" \\'
      expect(result).to include '-P "5432" \\'
      expect(result).to include '"example_credhub" < "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
      expect(result).to_not include '--ssl-ca=/var/vcap/jobs/credhub/config/database_ca.pem \\'
    end
    it "includes the mysql command with ssl properties when require_tls:true" do
      result = render_restore_erb("mysql", true)
      expect(result).to include('export MYSQLUTILS_DIR=/var/vcap/packages/database-backup-restorer-mysql')
      expect(result).to include '"${MYSQLUTILS_DIR}/bin/mysql" \\'
      expect(result).to include '-u "example_username" \\'
      expect(result).to include '-h "127.0.0.1" \\'
      expect(result).to include '-P "5432" \\'
      expect(result).to include '"example_credhub" < "${BBR_ARTIFACT_DIRECTORY}/credhubdb_dump"'
      expect(result).to include '--ssl-ca=/var/vcap/jobs/credhub/config/database_ca.pem \\'
    end
  end
  context "when db is not postgres or mysql" do
    it "logs that it skips this restore," do
      result = render_restore_erb("UNSUPPORTED", nil)
      expect(result).to_not include "/var/vcap/packages/database-backup-restorer-postgres/bin/pg_dump \\\n"
      expect(result).to_not include "/var/vcap/packages/database-backup-restorer-mysql/bin/mysqldump \\\n"
      expect(result).to include 'Skipping restore, as database is not Postgres or MySql'
    end
  end
  context "when not bootstrap vm" do
    it "logs that it delegates restore to the bootstrap vm" do
      result = render_restore_erb("mysql", false, false)
      expect(result).to_not include "/var/vcap/packages/database-backup-restorer-postgres/bin/pg_dump \\\n"
      expect(result).to_not include "/var/vcap/packages/database-backup-restorer-mysql/bin/mysqldump \\\n"
      expect(result).to include 'Deferring to the bootstrap VM to perform restore'
    end
  end
end
