# Known Issues with current CredHub versions

### Database migration failure

Some operators have reported failed upgrades between CredHub versions due to a database migration error caused by the Flyway utility.

The failure occurs when the `flyway_schema_history` (formerly called `schema_version`) table in the `credhub` database shows that a migration failed or did not happen when it actually did.

You will see some error like the one below:

```
Error starting ApplicationContext. To display the conditions report re-run your application with 'debug' enabled.
2019-06-20T12:35:30.502Z [main] .... ERROR --- SpringApplication: Application run failed org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'flywayInitializer' defined in class path resource [org/springframework/boot/autoconfigure/flyway/FlywayAutoConfiguration$FlywayConfiguration.class]: Invocation of init method failed; nested exception is org.flywaydb.core.api.FlywayException: Validate failed: Detected failed migration to version 49 (add path to permission table)
```

The migration failed because Flyway is trying to run migration `49`, but the migration was already run the last time this CredHub was upgraded, so the migration fails.

To prove that this failure occurred, you can look at the tables that would have been effected if the migration had run, and see that they have.

If you look at [migration 49](https://github.com/cloudfoundry-incubator/credhub/blob/6ecdf74ce2d5493aa7ab1d591351d5a46e1a3b3f/applications/credhub-api/src/main/resources/db/migration/postgres/V49__add_path_to_permission_table.sql) you see that it adds a column `path` to the table `permission`.

```sql
ALTER TABLE permission
  ADD COLUMN path VARCHAR(255);
```

So, if you connect to our `credhub` database and you see that the `permission` table has a column `path` you know you are seeing this issue.

#### Fix

The fix is to alter the `flyway_schema_history` table to show a successful migration.

If the last row has the migration, but it is marked as `false`, all you need to do is update the `success` column of that row to a true value (`t` or `1`, see other rows for an example).

If the migration is missing from the `flyway_schema_history` table, then you must add a new row where the `version` is the version of the migration that is failing and `success` is a true value.

Here are some pre-written migration rows that you can use as an example:

For example, if your upgrade is failing trying to run migration `47.1`, and it is not in the `flyway_schema_history` table, you should only run the first migration shown below.

```sql
insert into flyway_schema_history values (62, 47.1, 'add checksum column to credential table', 'SQL', 'V47_1__add_checksum_column_to_credential_table.sql', 1641678246, 'admin', '2019-05-24 14:32:22.809716', 10, 't');

insert into flyway_schema_history values (63, 47.2, 'insert checksum values for existing credentials', 'SPRING_JDBC', 'db.migration.common.V47_2__insert_checksum_values_for_existing_credentials', 'admin', '2019-05-24 14:32:22.809716', 10, 't');

insert into flyway_schema_history values (64, 47.3, 'modify constraints on columns with credential name', 'SQL', 'V47_3__modify_constraints_on_columns_with_credential_name.sql', -670736044, 'admin', '2019-05-24 14:32:22.809716', 10, 't');

insert into flyway_schema_history values (65, 48, 'drop audit tables', 'SQL', 'V48__drop_audit_tables.sql', -1223928835, 'admin', '2019-05-24 14:32:22.809716', 10, 't');

insert into flyway_schema_history values (66, 49, 'add path to permission table', 'SQL', 'V49__add_path_to_permission_table.sql', -1527845681, 'admin', '2019-05-24 14:32:22.809716', 10, 't');

insert into flyway_schema_history values (67, 50, 'add expiry date to certificate credential tabl', 'SQL', 'V50__add_expiry_date_to_certificate_credential_tabl.sql', -558260999, 'admin', '2019-05-24 14:32:22.809716', 10, 't');
```
