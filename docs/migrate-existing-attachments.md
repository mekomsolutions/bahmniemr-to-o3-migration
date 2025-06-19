# Migrate Existing Attachments

To migrate existing attachments (patient files & documents in Bahmni) in OpenMRS complex observations, you need to follow these steps:

### 1. Generate a CSV File for Migration

Run the following command to generate a CSV file that contains the current file paths and their new paths based on the UUIDs of the observations:

```bash
  
docker exec -it oz-hsc-uat-mysql-1 rm /tmp/migration_file_paths.csv # if exists

docker exec -it oz-hsc-uat-mysql-1 mysql -uroot -pmysql_root_password openmrs -e "
SELECT 'file_path', 'new_file_path'
UNION ALL
SELECT
    o.value_text AS file_path,
    CONCAT(
        REPLACE(SUBSTRING_INDEX(o.value_text, '/', 1), '/', '-'), 
        '-',
        REPLACE(REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(o.value_text, '/', -1), '.', 1), ' ', '-'), '/', '-'),
        '_', o.uuid,
        '.', SUBSTRING_INDEX(o.value_text, '.', -1)
    ) AS new_file_path
FROM obs o
JOIN concept c ON o.concept_id = c.concept_id
WHERE c.uuid LIKE '81f330b5-3f10-11e4-adec-0800271c1b75'
AND o.value_text IS NOT NULL
INTO OUTFILE '/tmp/migration_file_paths.csv'
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n';"
```

 > The command above will create a CSV file named `migration_file_paths.csv` in the `/tmp` directory of the MySQL container, containing the current file paths and their new paths based on the UUIDs.

### 2. Copy the CSV File to Host Machine
After generating the CSV file, you need to copy it from the MySQL container to your host machine. Use the following command:

```bash
    docker cp oz-hsc-uat-mysql-1:/tmp/migration_file_paths.csv migration_file_paths.csv
```

### 3. Run Migration Script for Complex Observations

Run the script from the root directory containing the unmigrated files:

```bash
  ./migrate_complex_obs.sh
```
> This script will read the `migration_file_paths.csv` file, create a directory named `complex_obs` in your home directory, and move the files from their current locations to the new paths based on the UUIDs.

### 4. Copy Moved Files to OpenMRS Container

Copy the moved files/documents into the `complex_obs` directory inside the OpenMRS container to ensure they are accessible by OpenMRS:

```bash
  docker cp /home/ubuntu/complex_obs/. ozone-hsc-openmrs-1:/openmrs/data/complex_obs/
```

### 5. Perform Database Migration for Complex Observations

Run the following database migration to convert the migrated observations on the file system into complex observations:

```bash
    docker exec -it ozone-hsc-mysql-1 mysql -uroot -pmysql_root_password openmrs -e "UPDATE obs o
    JOIN concept c ON o.concept_id = c.concept_id
    SET
        o.value_complex = CONCAT(
            'm3ks | instructions.default | ', 
            CASE 
                WHEN SUBSTRING_INDEX(o.value_text, '.', -1) IN ('jpeg', 'png') 
                     THEN CONCAT('image/', SUBSTRING_INDEX(o.value_text, '.', -1))
                ELSE CONCAT('application/', SUBSTRING_INDEX(o.value_text, '.', -1))
            END,
            ' | ',
            CONCAT(
                REPLACE(SUBSTRING_INDEX(o.value_text, '/', 1), '/', '-'), 
                '-',
                REPLACE(REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(o.value_text, '/', -1), '.', 1), ' ', '-'), '/', '-'),
                '_', o.uuid,
                '.', SUBSTRING_INDEX(o.value_text, '.', -1)
            )
        ),
        o.concept_id = (SELECT concept_id FROM concept WHERE uuid = 
            CASE 
                WHEN SUBSTRING_INDEX(o.value_text, '.', -1) IN ('jpeg', 'png') 
                    THEN '7cac8397-53cd-4f00-a6fe-028e8d743f8e'
                ELSE '42ed45fd-f3f6-44b6-bfc2-8bde1bb41e00'
            END LIMIT 1),
        o.value_text = NULL
    WHERE c.uuid LIKE '81f330b5-3f10-11e4-adec-0800271c1b75'
    AND o.value_text IS NOT NULL;"
```

### 6. Verify Migration

Check the OpenMRS database to ensure that the complex observations have been migrated correctly:

```bash
  docker exec -it ozone-hsc-mysql-1 mysql -uroot -pmysql_root_password openmrs -e "SELECT * FROM obs WHERE concept_id IN (SELECT concept_id FROM concept WHERE uuid IN ('7cac8397-53cd-4f00-a6fe-028e8d743f8e', '42ed45fd-f3f6-44b6-bfc2-8bde1bb41e00'));"
```

### 7. Clean Up
Remove the temporary CSV file from the MySQL container:

```bash
  docker exec -it oz-hsc-uat-mysql-1 rm /tmp/migration_file_paths.csv
```
Optionally, remove the `complex_obs` directory if it is no longer needed:

```bash
  rm -rf /home/ubuntu/complex_obs
```

### Notes
- Adjust the MySQL root password and container names as per your setup.
- The script assumes that the unmigrated files are located in `/home/ubuntu/complex_obs/`. Adjust the path as necessary.
- The script assumes that the OpenMRS database is named `openmrs`. Adjust the database name if it differs in your setup.
