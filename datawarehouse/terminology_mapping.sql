DROP TABLE IF EXISTS terminology_mapping;
CREATE TABLE terminology_mapping (source_code TEXT, source_codesystem TEXT, source_description TEXT, source_ancestor_code TEXT, target_code TEXT, target_codesystem TEXT, target_displayname TEXT, comment TEXT);

INSERT INTO terminology_mapping(source_code, source_codesystem, source_description, source_ancestor_code, target_code, target_codesystem, target_displayname, comment) VALUES
  ('Portavita407', '2.16.840.1.113883.2.4.3.31.2.1', 'Allergie',NULL, 420134006, '2.16.840.1.113883.6.96', 'Propensity to Adverse Reactions', NULL)
, ('Portavita408', '2.16.840.1.113883.2.4.3.31.2.1', 'Allergie en aspecifieke hyperactiviteit','Portavita408', 106190000, '2.16.840.1.113883.6.96', 'Allergic state', NULL)
, ('Portavita409', '2.16.840.1.113883.2.4.3.31.2.1', 'Last van kortademigheid, piepen of hoesten bij aspecifieke prikkels', 'Portavita408', 420881009, '2.16.840.1.113883.6.96', 'Allergic disorder by allergen type', NULL)
, ('Portavita410', '2.16.840.1.113883.2.4.3.31.2.1', 'Stoffige of vochtige omgeving', 'Portavita409', 390952000, '2.16.840.1.113883.6.96', 'Dust allergy', NULL)
, ('Portavita410', '2.16.840.1.113883.2.4.3.31.2.1', 'Stoffige of vochtige omgeving', 'Portavita409', 419474003, '2.16.840.1.113883.6.96', 'Allergy to mould', NULL)
, ('Portavita411', '2.16.840.1.113883.2.4.3.31.2.1', 'Toelichting stoffige of vochtige omgeving', 'Portavita410', 390952000, '2.16.840.1.113883.6.96', 'Dust allergy', NULL)
, ('Portavita411', '2.16.840.1.113883.2.4.3.31.2.1', 'Toelichting stoffige of vochtige omgeving', 'Portavita410', 419474003, '2.16.840.1.113883.6.96', 'Allergy to mould', NULL)
, ('Portavita412', '2.16.840.1.113883.2.4.3.31.2.1', 'Toelichting hooikoorts', NULL, 21719001, '2.16.840.1.113883.6.96', 'Allergic rhinitis due to pollen (disorder)', NULL)
, ('Portavita413', '2.16.840.1.113883.2.4.3.31.2.1', 'Toelichting contact met dieren', NULL, 232347008, '2.16.840.1.113883.6.96', 'Dander (animal) allergy (disorder)', NULL)
, ('Portavita414', '2.16.840.1.113883.2.4.3.31.2.1', 'Tabaksrook', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Allergy to substance', 'Hieraan zou je 102407002 Tobacco Smoke kunnen toevoegen')
, ('Portavita415', '2.16.840.1.113883.2.4.3.31.2.1', 'Tabaksrook', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Allergy to substance', 'Hieraan zou je 102407002 Tobacco Smoke kunnen toevoegen')
, ('Portavita416', '2.16.840.1.113883.2.4.3.31.2.1', 'Andere prikkels', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Allergy to substance',NULL)
, ('Portavita416', '2.16.840.1.113883.2.4.3.31.2.1', 'Andere prikkels', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Multiple environmental allergies',NULL)
, ('Portavita417', '2.16.840.1.113883.2.4.3.31.2.1', 'Andere prikkels', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Allergy to substance',NULL)
, ('Portavita417', '2.16.840.1.113883.2.4.3.31.2.1', 'Andere prikkels', 'Portavita409', 419199007, '2.16.840.1.113883.6.96', 'Multiple environmental allergies',NULL)
, ('Portavita418', '2.16.840.1.113883.2.4.3.31.2.1', 'Allergie test geindiceerd', 'Portavita407', 252569009, '2.16.840.1.113883.6.96', 'Test for allergens (procedure)', NULL)
, ('Portavita419', '2.16.840.1.113883.2.4.3.31.2.1', 'RAST geindiceerd', 'Portavita418', 104381000, '2.16.840.1.113883.6.96', 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita420', '2.16.840.1.113883.2.4.3.31.2.1', 'Uitslag eerder RAST-onderzoek', 'Portavita419', 104381000, '2.16.840.1.113883.6.96', 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita419', '2.16.840.1.113883.2.4.3.31.2.1', 'Datum eerdere RAST', 'Portavita419', 104381000, '2.16.840.1.113883.6.96', 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita422', '2.16.840.1.113883.2.4.3.31.2.1', 'Huidpriktest geindiceerd', 'Portavita418', 37968009, '2.16.840.1.113883.6.96', 'Prick test (procedure)', NULL)
, ('Portavita423', '2.16.840.1.113883.2.4.3.31.2.1', 'Uitslag eerdere huidpriktest', 'Portavita418', 37968009, '2.16.840.1.113883.6.96', 'Prick test (procedure)', NULL)
, ('Portavita424', '2.16.840.1.113883.2.4.3.31.2.1', 'Datum eerdere huidpriktest', 'Portavita418', 37968009, '2.16.840.1.113883.6.96', 'Prick test (procedure)', NULL)
;

