UPDATE concept_reference_source
SET hl7_code = 'SCT-legacy'
WHERE hl7_code = 'SCT'
  AND uuid LIKE '03f574a2-dce4-11ec-925e-0242ac160002';

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
WHERE ot.uuid = 'f8ae333e-9d1a-423e-a6a8-c3a0687ebcf2'
  AND o.order_id NOT IN (SELECT order_id FROM test_order);

UPDATE orders o
SET o.order_type_id = (SELECT order_type_id
                       FROM order_type
                       WHERE uuid = '52a447d3-a64a-11e3-9aeb-50e549534c5e'
    LIMIT 1)
WHERE o.order_type_id = (SELECT order_type_id
    FROM order_type
    WHERE uuid = 'f8ae333e-9d1a-423e-a6a8-c3a0687ebcf2'
    LIMIT 1);

-- create patientflags_tag_role table
CREATE TABLE openmrs.patientflags_tag_role
(
    tag_id INT         NOT NULL,
    role   VARCHAR(50) NOT NULL,
    CONSTRAINT patientflags_tag_role_ibfk_2 FOREIGN KEY (role) REFERENCES openmrs.role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
