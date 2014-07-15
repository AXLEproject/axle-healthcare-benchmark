/*
 * rim_dropforeignkeys.sql
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */
ALTER TABLE "AcknowledgementDetail" DROP CONSTRAINT IF EXISTS AcknowledgementDetail_acknowledgement_fkey;
ALTER TABLE "Acknowledgement" DROP CONSTRAINT IF EXISTS Acknowledgement_acknowledges_fkey;
ALTER TABLE "Acknowledgement" DROP CONSTRAINT IF EXISTS Acknowledgement_conveyingTransmission_fkey;
ALTER TABLE "ActRelationship" DROP CONSTRAINT IF EXISTS ActRelationship_source_fkey;
ALTER TABLE "ActRelationship" DROP CONSTRAINT IF EXISTS ActRelationship_target_fkey;
ALTER TABLE "Attachment" DROP CONSTRAINT IF EXISTS Attachment_transmission_fkey;
ALTER TABLE "AttentionLine" DROP CONSTRAINT IF EXISTS AttentionLine_transmission_fkey;
ALTER TABLE "Transmission" DROP CONSTRAINT IF EXISTS Transmission_batch_fkey;
ALTER TABLE "ControlAct" DROP CONSTRAINT IF EXISTS ControlAct_payload_fkey;
ALTER TABLE "LanguageCommunication" DROP CONSTRAINT IF EXISTS LanguageCommunication_entity_fkey;
ALTER TABLE "Parameter" DROP CONSTRAINT IF EXISTS Parameter_queryByParameter_fkey;
ALTER TABLE "Parameter" DROP CONSTRAINT IF EXISTS Parameter_parameterList_fkey;
ALTER TABLE "Participation" DROP CONSTRAINT IF EXISTS Participation_act_fkey;
ALTER TABLE "Participation" DROP CONSTRAINT IF EXISTS Participation_role_fkey;
ALTER TABLE "Role" DROP CONSTRAINT IF EXISTS Role_player_fkey;
ALTER TABLE "Role" DROP CONSTRAINT IF EXISTS Role_scoper_fkey;
ALTER TABLE "RoleLink" DROP CONSTRAINT IF EXISTS RoleLink_source_fkey;
ALTER TABLE "RoleLink" DROP CONSTRAINT IF EXISTS RoleLink_target_fkey;
ALTER TABLE "SortControl" DROP CONSTRAINT IF EXISTS SortControl_querySpec_fkey;
ALTER TABLE "TransmissionRelationship" DROP CONSTRAINT IF EXISTS TransmissionRelationship_source_fkey;
ALTER TABLE "TransmissionRelationship" DROP CONSTRAINT IF EXISTS TransmissionRelationship_target_fkey;
