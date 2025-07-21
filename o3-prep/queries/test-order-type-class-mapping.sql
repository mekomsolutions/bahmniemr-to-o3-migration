-- Remove Lab Order type class mappings
SET @lab_order_type_id = (SELECT order_type_id FROM openmrs.order_type WHERE uuid = 'f8ae333e-9d1a-423e-a6a8-c3a0687ebcf2');
DELETE FROM openmrs.order_type_class_map WHERE order_type_id = @lab_order_type_id;
-- Add Test Order Type class mappings
INSERT INTO openmrs.order_type_class_map (order_type_id, concept_class_id)
SELECT @lab_order_type_id, concept_class_id FROM concept_class WHERE name IN ('Test', 'LabTest', 'LabSet');
