USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetSoloLeagues]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetSoloLeagues] (
	@leagueName VARCHAR(100),
	@seasonKey INT
)
RETURNS @leagues TABLE (
    id VARCHAR(100),
    display VARCHAR(100),
	league_key VARCHAR(100)
)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 06/10/2015
-- Description: return solo leagues on leagueName and SMG_Default_Dates source
-- Update:		07/15/2015 - ikenticus - fixing for motor-sports => motor
-- =============================================
BEGIN

	DECLARE @league_source VARCHAR(100)
	DECLARE @league_ids TABLE (
		id VARCHAR(100)
	)

	SELECT TOP 1 @league_source = filter
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'source'

	IF (@league_source IS NULL AND @leagueName = 'motor-sports')
	BEGIN
		SET @leagueName = 'motor'

		SELECT TOP 1 @league_source = filter
		  FROM dbo.SMG_Default_Dates
		 WHERE league_key = @leagueName AND page = 'source'
	END

	INSERT INTO @league_ids (id)
	SELECT league_id
	  FROM dbo.SMG_Solo_Leagues
	 WHERE league_name = @leagueName AND season_key = @seasonKey
	 GROUP BY league_id

	INSERT INTO @leagues (id, display, league_key)
	SELECT i.id, l.league_display, l.league_key
	  FROM @league_ids AS i
	 INNER JOIN dbo.SMG_Mappings AS m ON m.value_to = i.id
	 INNER JOIN dbo.SMG_Solo_Leagues AS l ON l.league_key = m.value_from AND l.league_id = m.value_to
	 WHERE source = @league_source AND season_key = @seasonKey AND value_type = 'league'

	RETURN
END

GO
