/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Clean append_id.
 *
 * Requires serializable isolation level.
 */

DELETE FROM stream.append_id;
