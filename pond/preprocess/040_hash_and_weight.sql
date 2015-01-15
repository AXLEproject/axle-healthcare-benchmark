/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */


/*
 * Weights:
 *
 * - TZDU messages (TranZoom Dimension Update) messages carry more weight than
 *   others.
 * - For Roles, non null foreign key attributes means more information from
 *   associated Entities as well: more weight than others.
 * - id and name are important properties: more weight than others.
 *
 * Type 2 hash:
 *
 * - Less attributes than the weight calculation are used to calculate the type
 *   2 hash, most notably not part of the hash are:
 *
 *   - the external id field. id's are pointers to objects, but not part of the
 *     intrinsic properties of the real world objects themselves. Entity
 *     resolution of objects that have overlapping id's will result in a merge
 *     of the id field.
 *   - foreign key attributes like player, scoper. Though a change in playing
 *     entity or scoping organiztion would be a large change, the references to
 *     internal _id values are bound to change in future entity resolution
 *     updates. Also it is unlikely that the actual refered real world object
 *     of these references would change, as by definition a reference to a new
 *     scoper implies that a new role exists.
 */

UPDATE "Organization"
SET    _record_weight = 2000 * (_mif LIKE 'TZDU%')::int
               + 1000 * ("id" is not null)::int
               + 100  * ("name" is not null)::int
               + 1    * ("nullFlavor" is not null)::int
               + 1    * ("realmCode" is not null)::int
               + 1    * ("typeId" is not null)::int
               + 1    * ("templateId" is not null)::int
               + 1    * ("classCode" is not null)::int
               + 1    * ("determinerCode" is not null)::int
               + 1    * ("code" is not null)::int
               + 1    * ("quantity" is not null)::int
               + 1    * ("desc" is not null)::int
               + 1    * ("statusCode" is not null)::int
               + 1    * ("existenceTime" is not null)::int
               + 1    * ("telecom" is not null)::int
               + 1    * ("riskCode" is not null)::int
               + 1    * ("handlingCode" is not null)::int
               + 1    * ("addr" is not null)::int
               + 1    * ("standardIndustryClassCode" is not null)::int
,      _record_hash = md5(textin(record_out(ROW(
                    "nullFlavor",
                    "classCode",
                    "determinerCode",
                    "code",
                    "quantity",
                    "name",
                    "desc",
                    "statusCode",
                    "existenceTime",
                    "telecom",
                    "riskCode",
                    "handlingCode",
                    "addr",
                    "standardIndustryClassCode"
))));

UPDATE "Person"
SET    _record_weight = 2000 * (_mif LIKE 'TZDU%')::int
               + 1000 * ("id" is not null)::int
               + 100  * ("name" is not null)::int
               + 1    * ("nullFlavor" is not null)::int
               + 1    * ("realmCode" is not null)::int
               + 1    * ("typeId" is not null)::int
               + 1    * ("templateId" is not null)::int
               + 1    * ("classCode" is not null)::int
               + 1    * ("determinerCode" is not null)::int
               + 1    * ("code" is not null)::int
               + 1    * ("quantity" is not null)::int
               + 1    * ("desc" is not null)::int
               + 1    * ("statusCode" is not null)::int
               + 1    * ("existenceTime" is not null)::int
               + 1    * ("telecom" is not null)::int
               + 1    * ("riskCode" is not null)::int
               + 1    * ("handlingCode" is not null)::int
               + 1    * ("administrativeGenderCode" is not null)::int
               + 1    * ("birthTime" is not null)::int
               + 1    * ("deceasedInd" is not null)::int
               + 1    * ("deceasedTime" is not null)::int
               + 1    * ("multipleBirthInd" is not null)::int
               + 1    * ("multipleBirthOrderNumber" is not null)::int
               + 1    * ("organDonorInd" is not null)::int
               + 1    * ("addr" is not null)::int
               + 1    * ("maritalStatusCode" is not null)::int
               + 1    * ("educationLevelCode" is not null)::int
               + 1    * ("disabilityCode" is not null)::int
               + 1    * ("livingArrangementCode" is not null)::int
               + 1    * ("religiousAffiliationCode" is not null)::int
               + 1    * ("raceCode" is not null)::int
               + 1    * ("ethnicGroupCode" is not null)::int
,      _record_hash = md5(textin(record_out(ROW(
                    "nullFlavor",
                    "classCode",
                    "determinerCode",
                    "code",
                    "quantity",
                    "name",
                    "desc",
                    "statusCode",
                    "existenceTime",
                    "telecom",
                    "riskCode",
                    "handlingCode",
                    "administrativeGenderCode",
                    "birthTime",
                    "deceasedInd",
                    "deceasedTime",
                    "multipleBirthInd",
                    "multipleBirthOrderNumber",
                    "organDonorInd",
                    "addr",
                    "maritalStatusCode",
                    "educationLevelCode",
                    "disabilityCode",
                    "livingArrangementCode",
                    "religiousAffiliationCode",
                    "raceCode",
                    "ethnicGroupCode"
))));

UPDATE ONLY "Role"
SET    _record_weight = 2000 * (_mif LIKE 'TZDU%')::int
               + 1000 * ("id" is not null)::int
               + 100  * (player is not null)::int
               + 100  * (scoper is not null)::int
               + 100  * ("name" is not null)::int
               + 1    * ("nullFlavor" is not null)::int
               + 1    * ("realmCode" is not null)::int
               + 1    * ("typeId" is not null)::int
               + 1    * ("templateId" is not null)::int
               + 1    * ("classCode" is not null)::int
               + 1    * ("code" is not null)::int
               + 1    * ("negationInd" is not null)::int
               + 1    * ("addr" is not null)::int
               + 1    * ("telecom" is not null)::int
               + 1    * ("statusCode" is not null)::int
               + 1    * ("effectiveTime" is not null)::int
               + 1    * ("certificateText" is not null)::int
               + 1    * ("confidentialityCode" is not null)::int
               + 1    * ("quantity" is not null)::int
               + 1    * ("priorityNumber" is not null)::int
               + 1    * ("positionNumber" is not null)::int
,      _record_hash = md5(textin(record_out(ROW(
                    "nullFlavor",
                    "classCode",
                    "code",
                    "negationInd",
                    "name",
                    "addr",
                    "telecom",
                    "statusCode",
                    "effectiveTime",
                    "certificateText",
                    "confidentialityCode",
                    "quantity",
                    "priorityNumber",
                    "positionNumber"
))));


UPDATE ONLY "Patient"
SET    _record_weight = 2000 * (_mif LIKE 'TZDU%')::int
               + 1000 * ("id" is not null)::int
               + 100  * (player is not null)::int
               + 100  * (scoper is not null)::int
               + 100  * ("name" is not null)::int
               + 1    * ("nullFlavor" is not null)::int
               + 1    * ("realmCode" is not null)::int
               + 1    * ("typeId" is not null)::int
               + 1    * ("templateId" is not null)::int
               + 1    * ("classCode" is not null)::int
               + 1    * ("code" is not null)::int
               + 1    * ("negationInd" is not null)::int
               + 1    * ("addr" is not null)::int
               + 1    * ("telecom" is not null)::int
               + 1    * ("statusCode" is not null)::int
               + 1    * ("effectiveTime" is not null)::int
               + 1    * ("certificateText" is not null)::int
               + 1    * ("confidentialityCode" is not null)::int
               + 1    * ("quantity" is not null)::int
               + 1    * ("priorityNumber" is not null)::int
               + 1    * ("positionNumber" is not null)::int
               + 1    * ("veryImportantPersonCode" is not null)::int
,      _record_hash = md5(textin(record_out(ROW(
                    "nullFlavor",
                    "classCode",
                    "code",
                    "negationInd",
                    "name",
                    "addr",
                    "telecom",
                    "statusCode",
                    "effectiveTime",
                    "certificateText",
                    "confidentialityCode",
                    "quantity",
                    "priorityNumber",
                    "positionNumber",
                    "veryImportantPersonCode"
))));

UPDATE ONLY "LicensedEntity"
SET    _record_weight = 2000 * (_mif LIKE 'TZDU%')::int
               + 1000 * ("id" is not null)::int
               + 100  * (player is not null)::int
               + 100  * (scoper is not null)::int
               + 100  * ("name" is not null)::int
               + 1    * ("nullFlavor" is not null)::int
               + 1    * ("realmCode" is not null)::int
               + 1    * ("typeId" is not null)::int
               + 1    * ("templateId" is not null)::int
               + 1    * ("classCode" is not null)::int
               + 1    * ("code" is not null)::int
               + 1    * ("negationInd" is not null)::int
               + 1    * ("addr" is not null)::int
               + 1    * ("telecom" is not null)::int
               + 1    * ("statusCode" is not null)::int
               + 1    * ("effectiveTime" is not null)::int
               + 1    * ("certificateText" is not null)::int
               + 1    * ("confidentialityCode" is not null)::int
               + 1    * ("quantity" is not null)::int
               + 1    * ("priorityNumber" is not null)::int
               + 1    * ("positionNumber" is not null)::int
               + 1    * ("recertificationTime" is not null)::int
,      _record_hash = md5(textin(record_out(ROW(
                    "nullFlavor",
                    "classCode",
                    "code",
                    "negationInd",
                    "name",
                    "addr",
                    "telecom",
                    "statusCode",
                    "effectiveTime",
                    "certificateText",
                    "confidentialityCode",
                    "quantity",
                    "priorityNumber",
                    "positionNumber",
                    "recertificationTime"
))));

/***
select _mif, "classCode", avg(_record_weight) from "Entity" group by _mif, "classCode";
select _mif, "classCode", avg(_record_weight) from "Role" group by _mif, "classCode";

explain analyze select distinct _mif, "classCode" from "Entity" where _record_weight is null;
explain analyze select distinct _mif, "classCode" from "Role" where _record_weight is null;
***/