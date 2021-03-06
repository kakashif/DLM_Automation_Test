USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamRosterFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamRosterFilters_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT,
	@level VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/24/2013
-- Description: get team roster filters
-- Update:      09/30/2013 - John Lin - remove default parameters
--              10/22/2013 - ikenticus: switching to leagueName and teamSlug
--				02/24/2014 - ikenticus: adding full roster level to NBA/WNBA
--              08/01/2014 - John Lin - available year is roster/team/league join
--				06/30/2015 - ikenticus: only displaying 'full' for TSN/XTS league_keys
--              07/23/2015 - John Lin - update WNBA
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    -- levels
    DECLARE @levels TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
	
	INSERT INTO @levels (id, display)
	VALUES ('active', 'Active')

	IF @leagueName IN ('mlb', 'nhl', 'nfl', 'nba', 'wnba')
	BEGIN
		INSERT INTO @levels (id, display)
		VALUES ('full', 'Full')
	END

    -- verify level
   	IF NOT EXISTS (SELECT 1 FROM @levels WHERE id = @level)
	BEGIN
	    SELECT TOP 1 @level = id FROM @levels 
	END


	-- Retrieving team_key from teamSlug
	DECLARE @team_key VARCHAR(100)

    SELECT TOP 1 @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND team_slug = @teamSlug
	ORDER BY season_key DESC


    -- seasons
    DECLARE @seasons TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
	
    INSERT INTO @seasons (id, display)
    SELECT sr.season_key,
		   (CASE
		       WHEN @leagueName IN ('mlb', 'mls', 'wnba') THEN CAST(sr.season_key AS VARCHAR) + ' Season'
		       WHEN @leagueName IN ('natl', 'wwc') THEN CAST(sr.season_key AS VARCHAR) 
			   ELSE CAST((sr.season_key) AS VARCHAR) + '-' + SUBSTRING(CAST(sr.season_key + 1 AS VARCHAR), 3, 4) + ' Season'
	       END)
      FROM dbo.SMG_Rosters sr
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = sr.league_key AND st.season_key = sr.season_key
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = st.league_key AND sl.season_key = st.season_key
	 WHERE sr.league_key = @league_key AND sr.team_key = @team_key
	 GROUP BY sr.season_key
	 ORDER BY sr.season_key DESC

	-- insert current season if empty
   	IF NOT EXISTS (SELECT 1 FROM @seasons)
	BEGIN
		INSERT INTO @seasons (id, display)
		VALUES (YEAR(GETDATE()), 'Current Season')
	END

    -- verify season
   	IF NOT EXISTS (SELECT 1 FROM @seasons WHERE id = @seasonKey)
	BEGIN
	    SELECT TOP 1 @seasonKey = id
	      FROM @seasons
	     ORDER BY id DESC 
	END


    SELECT
    (
        SELECT id, display
        FROM @levels
        FOR XML RAW('level'), TYPE
    ),
    (
        SELECT id, display
        FROM @seasons
         FOR XML RAW('year'), TYPE
    ),
    (
        SELECT @level AS [level], @seasonKey AS year
        FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END


GO
