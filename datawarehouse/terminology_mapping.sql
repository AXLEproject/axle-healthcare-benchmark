DROP TABLE IF EXISTS terminology_mapping;
CREATE TABLE terminology_mapping (source_code TEXT, source_description TEXT, source_ancestor_code TEXT, target_code BIGINT, target_displayname TEXT, comment TEXT);

INSERT INTO terminology_mapping(source_code, source_description, source_ancestor_code, target_code, target_displayname, comment) VALUES
  ('Portavita407', 'Allergie',NULL, 420134006, 'Propensity to Adverse Reactions', NULL)
, ('Portavita408', 'Allergie en aspecifieke hyperactiviteit','Portavita408', 106190000, 'Allergic state', NULL)
, ('Portavita409', 'Last van kortademigheid, piepen of hoesten bij aspecifieke prikkels', 'Portavita408', 420881009, 'Allergic disorder by allergen type', NULL)
, ('Portavita410', 'Stoffige of vochtige omgeving', 'Portavita409',390952000, 'Dust allergy', NULL)
, ('Portavita410', 'Stoffige of vochtige omgeving', 'Portavita409', 419474003, 'Allergy to mould', NULL)
, ('Portavita411', 'Toelichting stoffige of vochtige omgeving', 'Portavita410', 390952000, 'Dust allergy', NULL)
, ('Portavita411', 'Toelichting stoffige of vochtige omgeving', 'Portavita410', 419474003, 'Allergy to mould', NULL)
, ('Portavita412', 'Toelichting hooikoorts', NULL, 21719001, 'Allergic rhinitis due to pollen (disorder)', NULL)
, ('Portavita413', 'Toelichting contact met dieren', NULL, 232347008, 'Dander (animal) allergy (disorder)', NULL)
, ('Portavita414', 'Tabaksrook', 'Portavita409', 419199007,'Allergy to substance', 'Hieraan zou je 102407002 Tobacco Smoke kunnen toevoegen')
, ('Portavita415', 'Tabaksrook', 'Portavita409', 419199007,'Allergy to substance', 'Hieraan zou je 102407002 Tobacco Smoke kunnen toevoegen')
, ('Portavita416', 'Andere prikkels', 'Portavita409', 419199007,'Allergy to substance',NULL)
, ('Portavita416', 'Andere prikkels', 'Portavita409', 419199007,'Multiple environmental allergies',NULL)
, ('Portavita417', 'Andere prikkels', 'Portavita409', 419199007,'Allergy to substance',NULL)
, ('Portavita417', 'Andere prikkels', 'Portavita409', 419199007,'Multiple environmental allergies',NULL)
, ('Portavita418', 'Allergie test geindiceerd', 'Portavita407', 252569009, 'Test for allergens (procedure)', NULL)
, ('Portavita419', 'RAST geindiceerd', 'Portavita418', 104381000, 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita420', 'Uitslag eerder RAST-onderzoek', 'Portavita419', 104381000, 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita419', 'Datum eerdere RAST', 'Portavita419', 104381000, 'Allergen specific IgE antibody measurement (procedure)', NULL)
, ('Portavita422', 'Huidpriktest geindiceerd', 'Portavita418', 37968009, 'Prick test (procedure)', NULL)
, ('Portavita423', 'Uitslag eerdere huidpriktest', 'Portavita418', 37968009, 'Prick test (procedure)', NULL)
, ('Portavita424', 'Datum eerdere huidpriktest', 'Portavita418', 37968009, 'Prick test (procedure)', NULL)
;

