# Bahmni EMR to OpenMRS 3 Migration Guide

## Update OpenMRS Core database through it's different versions

### 1. Copy the Database Backup
- Copy the `dump.sql` database backup file to:
    - `sql/mysql`

### 2. Rename the Dump
- Rename the `dump.sql` file to `openmrs.sql`.

### 3. Spin-up MySQL and OpenMRS Services
- Spin-up the `mysql` and `openmrs` services only:
    ```bash
    docker compose up mysql openmrs --build
    ```

### 4. Access OpenMRS
- Access OpenMRS at:
    - [localhost/openmrs](http://localhost/openmrs)

### 5. Login to OpenMRS
- Login using:
    - Username: `admin`
    - Password: `Admin123`

### 6. Proceed with Liquibase Migrations
- To initiate the migration, click the forward button at the bottom of the page.

### 7. Wait for Liquibase Migrations
- Wait for all Liquibase migrations to complete.

### 8. Verify OpenMRS Version
- After migrations are complete, access OpenMRS at:
    - [localhost/openmrs](http://localhost/openmrs)
- It should display:
    - `OpenMRS Platform 2.* Running!`

### 9. Terminate Containers and Repeat Migration for Other Versions
- Terminate the docker containers and repeat steps 3 to 7 for the following OpenMRS Core versions:
    - 2.2.1
    - 2.3.6
    - 2.4.5
    - 2.5.12

    **Important Notes**:
    - Do **not** terminate the containers when running version 2.5.12 as its corresponding database will need to be backed up in the next step.
    - To change the OpenMRS version, edit the `OPENMRS_WAR_URL` in the `./openmrs/Dockerfile`.

### 10. Backup the OpenMRS Database
- In a separate terminal, backup the updated OpenMRS database:
    - Follow the instructions in the "Backup databases and filestores" section in the README. 
    - Only run the `openmrs-db-backup` service.

### 11. Stop the Containers
- Stop the containers by terminating the previous command (`docker compose up mysql openmrs --build`) in the terminal where it's running:
    - Use `Ctrl + C` to stop the containers.

### 12. Restore Database to Ozone
- Using the backup OpenMRS dump, restore it into Ozone appropriately, and start only the `mysql` instance.

### 13. Run Queries for Preparations
- Run the following queries to prepare the OpenMRS service:

    ```sql
    UPDATE concept_reference_source 
    SET hl7_code = 'SCT-legacy' 
    WHERE hl7_code = 'SCT' AND uuid LIKE '03f574a2-dce4-11ec-925e-0242ac160002';

    UPDATE concept 
    SET uuid = CONCAT(uuid, REPEAT('A', 36 - LENGTH(uuid))) 
    WHERE uuid IN ('5090AAAAAAAAAAAAAAAAAAAAAAAAAAAA', '5089AAAAAAAAAAAAAAAAAAAAAAAAAAAA');

    UPDATE drug_order 
    SET dosing_type = 'org.openmrs.SimpleDosingInstructions' 
    WHERE dosing_type = 'org.openmrs.module.bahmniemrapi.drugorder.dosinginstructions.FlexibleDosingInstructions';

    INSERT INTO test_order (order_id) 
    SELECT o.order_id 
    FROM orders o 
    JOIN order_type ot ON o.order_type_id = ot.order_type_id 
    WHERE ot.uuid = 'f8ae333e-9d1a-423e-a6a8-c3a0687ebcf2';

    UPDATE orders o 
    SET o.order_type_id = (SELECT order_type_id 
                           FROM order_type 
                           WHERE uuid LIKE '52a447d3-a64a-11e3-9aeb-50e549534c5e' 
                           LIMIT 1) 
    WHERE o.order_type_id = (SELECT order_type_id 
                              FROM order_type 
                              WHERE uuid LIKE 'f8ae333e-9d1a-423e-a6a8-c3a0687ebcf2' 
                              LIMIT 1);
    
    CREATE TABLE openmrs.patientflags_tag_role (
        tag_id INT NOT NULL,
        role VARCHAR(50) NOT NULL,
        CONSTRAINT patientflags_tag_role_ibfk_2 FOREIGN KEY (role) REFERENCES openmrs.role(role)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
    ```

    > The above query helps avoid errors during the `patientflags` module Liquibase migration:
    > `ERROR 1005 (HY000): Can't create table 'openmrs.patientflags_tag_role' (errno: 150 "Foreign key constraint is incorrectly formed")`.

### 14. Start Remaining Containers
- Start the remaining containers in addition to the already running MySQL containers.

### 15. Restart Ozone Containers
- Restart all Ozone containers. In some cases, it may be necessary to run the following query on the OpenMRS database:

    ```sql
    UPDATE liquibasechangeloglock 
    SET LOCKED = '0', LOCKEDBY = NULL, LOCKGRANTED = NULL 
    WHERE ID = 1;
    ```

### 16. Rebuild Search Index
- Access the running Ozone-based OpenMRS instance and rebuild the search index.

## Migrate existing data to make it O3 compliant

### 17. Migrate Encounter Diagnoses
- Migrate encounter diagnoses from `obs` to their specialized data model:
    - Retire the following duplicate OCL concepts:
        - `name: Diagnosis or problem`, `non-coded`, `uuid: 161602AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`
        - `name: Problem list`, `uuid: 1284AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`

    - Navigate to `Administration > Migrate Existing Diagnosis Data` in the legacy UI and proceed with the migration (this may take some time).

    - To verify the completion of the migration, run the following query:

    ```sql
    select count(*) from encounter_diagnosis;
    ```

    Ensure that the count remains consistent for at least 1 minute.


## Migrate existing attahcments

### 18. Generate CSV for Migration Files
- Run the following commands to generate a CSV file that maps files on the filesystem to the corresponding obs:

    ```bash
    docker exec -it ozone-hsc-mysql-1 rm /tmp/migration_file_paths.csv # if exists

    docker exec -it ozone-hsc-mysql-1 mysql -uroot -pmysql_root_password openmrs -e "
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
    LINES TERMINATED BY '\n';
    "

    docker cp ozone-hsc-mysql-1:/tmp/migration_file_paths.csv migration_file_paths.csv
    ```

---

### 19. Run Complex Observation Migration Script

1. Create the script file:

    ```bash
    touch complex_obs_migration_script.sh
    ```

2. Open the script in an editor:

    ```bash
    nano complex_obs_migration_script.sh
    ```

3. Copy the following script and save it:

    ```bash
    #!/bin/bash

    # Get the directory where the script is located
    script_dir="$(dirname "$(realpath "$0")")"

    # Set the CSV file name (ensure this file exists and is in the same directory as the script)
    csv_file="$script_dir/migration_file_paths.csv"

    # Check if the CSV file exists
    if [[ ! -f "$csv_file" ]]; then
        echo "CSV file not found!"
        exit 1
    fi

    # Read the CSV file line by line
    while IFS=',' read -r file_path new_file_path; do
        # Skip the header row
        if [[ "$file_path" == "file_path" ]]; then
            continue
        fi

        # Make file paths relative to the script's directory
        abs_file_path="$script_dir/$file_path"
        abs_new_file_path="/home/ubuntu/complex_obs/$new_file_path"

        # Check if the source file exists
        if [[ ! -f "$abs_file_path" ]]; then
            echo "File not found: $abs_file_path"
            continue
        fi

        # Create the target directory if it does not exist
        target_dir=$(dirname "$abs_new_file_path")
        if [[ ! -d "$target_dir" ]]; then
            echo "Target directory does not exist, creating: $target_dir"
            mkdir -p "$target_dir"
        fi

        # Move the file
        mv "$abs_file_path" "$abs_new_file_path"
        if [[ $? -eq 0 ]]; then
            echo "Moved: $abs_file_path to $abs_new_file_path"
        else
            echo "Failed to move: $abs_file_path"
        fi
    done < "$csv_file"

    echo "File move process completed."
    ```

4. Save the script and give it execute permissions:

    ```bash
    chmod +x complex_obs_migration_script.sh
    ```

5. Run the script from the root directory containing the unmigrated files:

    ```bash
    ./complex_obs_migration_script.sh
    ```

---

### 20. Copy Files into the OpenMRS Container

- Copy the moved files/documents into the `complex_obs` directory inside the OpenMRS container:

    ```bash
    docker cp /home/ubuntu/complex_obs/. ozone-hsc-openmrs-1:/openmrs/data/complex_obs/
    ```

### 21. Perform Database Migration for Complex Observations

- Run the following database migration to convert the migrated observations on the file system into complex observations:

    ```bash
    docker exec -it ozone-hsc-mysql-1 mysql -uroot -pmysql_root_password openmrs -e "
    UPDATE obs o
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

---

