USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnEventId]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnEventId]
(
    @eventKey VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 08/03/2015
-- Description: return event_id from given @eventKey
-- Update:		08/04/2015 - ikenticus - using RIGHT and less REVERSEs for efficiency
-- =============================================
BEGIN

	DECLARE @event_id VARCHAR(100)

	SET @event_id = CASE  -- xmlteam, sdi, stats (cups), stats (other)

					WHEN @eventKey LIKE '%-e.%'		-- xmlteam: l.mlb.com-2015-e.1234
					THEN RIGHT(@eventKey, CHARINDEX('.e-', REVERSE(@eventKey)) - 1)

					WHEN @eventKey LIKE '%:%'		-- sdi: /sport/baseball/competition:1234567
					THEN RIGHT(@eventKey, CHARINDEX(':', REVERSE(@eventKey)) - 1)

					WHEN @eventKey LIKE '%.%'		-- stats (tennis cups = tourney.venue): 1234567.12345
					THEN RIGHT(@eventKey, CHARINDEX('.', REVERSE(@eventKey)) - 1)

					ELSE @eventKey					-- stats: 1234567
					END

	RETURN @event_id

END


GO
