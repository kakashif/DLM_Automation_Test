USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetLeagueKey]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetLeagueKey] (
	@leagueName VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 05/14/2015
-- Description: return league_key base on leagueName and SMG_Default_Dates source
-- =============================================
BEGIN

    DECLARE @league_key VARCHAR(100)
	DECLARE @league_source VARCHAR(100)

	SELECT TOP 1 @league_source = filter
	  FROM dbo.SMG_Default_Dates
	 WHERE page = 'source' AND league_key = @leagueName
	
	IF (@league_source IS NOT NULL)
	BEGIN
		SELECT TOP 1 @league_key = value_from
		  FROM dbo.SMG_Mappings
		 WHERE value_type = 'league' AND value_to = @leagueName AND source = @league_source
	END
	ELSE
	BEGIN
		IF (@leagueName IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
		BEGIN
			SELECT @league_key = league_display_name
			  FROM dbo.USAT_leagues
			 WHERE league_name = LOWER(@leagueName)
		END
		ELSE IF (@leagueName = 'epl')
		BEGIN
			SET @league_key = 'premierleague'
		END
		ELSE
		BEGIN
			SET @league_key = @leagueName
		END
	END

	RETURN @league_key

END

GO
