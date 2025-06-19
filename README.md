# Bahmni EMR to OpenMRS 3 Migration Guide

## Prerequisites

Before starting the migration process, ensure you have completed the following preparations:

- **OpenMRS Version**: Confirm the current OpenMRS core version running in your Bahmni environment. 
  - The migration guide is designed for OpenMRS core versions 2.1.7, 2.2.1, 2.3.6, 2.4.5, 2.5.14, and 2.6.14. Adjust the `OPENMRS_WAR_URL` in the `./openmrs/Dockerfile` to match the desired version.
- **Docker & Compose Setup**: Docker and Docker Compose are installed on the migration server or on the machine where the migration will be performed.
- **Sufficient Disk Space**: Ensure ample disk space is available for database exports, backups, and restored instances.
- **Database Tools**: `mysqldump` and `mysql` command-line tools are installed and accessible.
- **Downtime Window**: A scheduled downtime window to ensure a consistent database export.
- **Backup**: A complete backup of the Bahmni OpenMRS database is taken before starting the migration process.

## Migration Steps

Execute the following steps to migrate from Bahmni EMR to OpenMRS 3:

### 1. Copy the Database Backup
- Copy the `dump.sql` database backup file to:
    - `sql/mysql`

> Ensure the `dump.sql` file is the latest backup of your Bahmni OpenMRS database. 
> It should be a complete export of the OpenMRS database from your Bahmni instance.

### 2. Rename the Dump
- Rename the `dump.sql` file to `openmrs.sql`. This file will be used to initialize the OpenMRS database in the Docker container.

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
    - 2.5.14
    - 2.6.14

    **Important Notes**:
    - Do **not** terminate the containers when running version 2.6.14 as its corresponding database will need to be backed up in the next step.
    - To change the OpenMRS version, edit the `OPENMRS_WAR_URL` in the `./openmrs/Dockerfile`.

### 10. Backup the OpenMRS Database
- In a separate terminal, back up the updated OpenMRS database:
    - Run `docker compose -f back.docker-compose.yml up -d`

### 11. Stop the Containers
- Stop the containers by terminating the previous command (`docker compose up mysql openmrs --build`) in the terminal where it's running:
    - Use `Ctrl + C` to stop the containers.

### 12. Restore Database to Ozone
- Using the backup OpenMRS dump, restore it into Ozone appropriately, and start only the `mysql` instance.

### 13. Run Queries for Preparations
- Run the following queries to prepare the OpenMRS service:

    ```bash
    cat ~/migration/o3-prep/queries/prepare_openmrs.sql | docker exec -i oz-hsc-uat-mysql-1 mysql -uopenmrs -p<password> openmrs
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
- This query releases the Liquibase changelog lock, allowing the migration to proceed without issues.

### 16. Rebuild Search Index
- Navigate to the OpenMRS admin page at:
    - [localhost/openmrs](http://localhost/openmrs)
- Go to Administration > Search Index > Rebuild Search Index.
- Click the "Rebuild Search Index" button to rebuild the search index.

Rebuilding the search index is crucial to ensure that all migrated data is searchable and indexed correctly.
It may take some time depending on the amount of data in the system.
After the process is complete,
you should see a confirmation message indicating that the search index has been successfully rebuilt.

### 17. Migrate Encounter Diagnoses

- Follow [migrate encounter diagnoses guide.](docs/migrate-encounter-diagnoses.md)

### 18. Migrate Existing Attachments

- Follow [migrate existing attachments guide.](docs/migrate-existing-attachments.md)
