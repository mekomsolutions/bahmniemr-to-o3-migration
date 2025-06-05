# Migrate Encounter Diagnoses

Migrate encounter diagnoses from `obs` to their specialized data model `encounter_diagnosis`:

- There maybe some duplicate concepts that need to be retired before proceeding with the migration. Use the script `scripts/retire-concepts.sh` to retire these concepts. The scripts expect a file `concepts_to_retire.txt` in the same directory, which should contain the UUIDs of the concepts to be retired. For example, the file can contain:

    ```txt
    81f330b5-3f10-11e4-adec-0800271c1b75
    2e6513f6-4c91-42df-8b26-41d7a03a4712
    ```

- Navigate to `Administration > Migrate Existing Diagnosis Data` in the legacy UI and proceed with the migration (this may take some time, roughly around 20-25 mins).

- To verify the completion of the migration, run the following query:

    ```sql
    select count(*) from encounter_diagnosis;
    ```
    Ensure that the count remains consistent for at least 1 minute.
