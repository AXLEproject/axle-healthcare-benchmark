/*
 * (c) 2014 Portavita B.V.
 * All rights reserved
 *
 * Create auxiliary tables for act-care provision links and opt-out consent.
 */

CREATE TABLE "LinkActPcpr"(
	"actId"		     bigint,
	"careProvision"	 "CD",
	"patientId"      "SET_II",
	PRIMARY KEY("actId", "careProvision")
);

CREATE TABLE "OptOutConsent"(
	"patientId"		"SET_II",
	"careProvision"	"CD",
	PRIMARY KEY ("patientId", "careProvision")
);
