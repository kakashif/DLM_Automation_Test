USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetSoloFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetSoloFilters_XML]
    @leagueName VARCHAR(100),
	@page VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100),
    @pageFilter VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 10/10/2013
-- Description: get filters for Solo Sports
-- Update:		10/12/2013 - ikenticus: making eventId into generic pageFilter for multiple usage
--				12/15/2014 - ikenticus: reformatting
--				01/30/2015 - ikenticus: using Golf league display instead of hard-coding
--				02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/23/2015 - ikenticus: fixing season_keys default
--				03/24/2015 - ikenticus: fixing motor-sports (non-nascar)
--				03/31/2015 - ikenticus: omit leagueId in query when NULL
--				04/07/2015 - ikenticus: need to check that leagueId is string.Empty for C# calls
--				04/10/2015 - ikenticus: tweaks needed for STATS tennis data
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				05/01/2015 - ikenticus: fixing incorrect SMG_Default_Dates/SMG_Mappings logic for leagues
--				06/12/2015 - ikenticus: using new functions to limit filters to current source
--				07/02/2015 - ikenticus: fixing results filter for Tennis cups, removing postponed events from dropdown
--				07/07/2015 - ikenticus: fixing results filter for Golf, removing scoring-system pre-events from dropdown
--				07/15/2015 - ikenticus: fixing motor[-sports] logic
--				08/07/2015 - ikenticus: removing league_source block since SMG_fnGetSoloLeagues handles that now
--				09/01/2015 - ikenticus: limit golf results to events having score, extend display for nascar event_name
--				09/02/2015 - ikenticus: crop nascar dropdown event_name sponsors to prevent wrapping
--				09/10/2015 - ikenticus: use SMG_Solo_Archive before SMG_Solo_Results for efficiency
--				09/30/2015 - ikenticus: use current season for schedules as default
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	IF (@leagueName = 'motor-sports')
	BEGIN
		SET @leagueName = 'motor'
	END

	-- season_keys
    DECLARE @season_keys TABLE (
	    season_key INT,
		season_display VARCHAR(100)
	)

	IF @page = 'schedule'
	BEGIN
		IF (@leagueId IS NULL OR @leagueId = '')
		BEGIN
			INSERT INTO @season_keys (season_key)
			SELECT season_key
			  FROM dbo.SMG_Solo_Leagues
			 WHERE league_name = @leagueName AND
				   league_key IN (SELECT league_key FROM dbo.SMG_fnGetSoloLeagues(@leagueName, season_key))
			 GROUP BY season_key
			 ORDER BY season_key DESC
		END
		ELSE
		BEGIN
			INSERT INTO @season_keys (season_key)
			SELECT season_key
			  FROM dbo.SMG_Solo_Leagues
			 WHERE league_name = @leagueName AND league_id = @leagueId AND
				   league_key IN (SELECT league_key FROM dbo.SMG_fnGetSoloLeagues(@leagueName, season_key))
			 GROUP BY season_key
			 ORDER BY season_key DESC
		END

		-- Obtain current season first, if available
		IF NOT EXISTS (SELECT 1 FROM @season_keys WHERE season_key = @seasonKey)
		BEGIN
			SELECT TOP 1 @seasonKey = season_key
			  FROM @season_keys
			 WHERE season_key = YEAR(GETDATE())
			 ORDER BY season_key DESC
		END
	END
	ELSE IF @page = 'standings'
	BEGIN
		INSERT INTO @season_keys (season_key)
		SELECT s.season_key
		  FROM dbo.SMG_Solo_Standings AS s
		 INNER JOIN dbo.SMG_Solo_Leagues AS l ON l.league_key = s.league_key AND l.league_name = @leagueName
		 WHERE s.league_key IN (SELECT league_key FROM dbo.SMG_fnGetSoloLeagues(@leagueName, s.season_key))
		 GROUP BY s.season_key
		 ORDER BY s.season_key DESC
	END
	ELSE IF @page = 'results'
	BEGIN
		INSERT INTO @season_keys (season_key)
		SELECT s.season_key
		  FROM dbo.SMG_Solo_Archive AS s
		 INNER JOIN dbo.SMG_Solo_Leagues AS l ON l.league_id = s.league_id AND l.league_name = @leagueName
		 WHERE l.league_key IN (SELECT league_key FROM dbo.SMG_fnGetSoloLeagues(@leagueName, s.season_key))
		 GROUP BY s.season_key
		 ORDER BY s.season_key DESC

		-- Check Results only if Archive returns NULL
		IF NOT EXISTS (SELECT 1 FROM @season_keys)
		BEGIN
			INSERT INTO @season_keys (season_key)
			SELECT s.season_key
			  FROM dbo.SMG_Solo_Results AS s
			 INNER JOIN dbo.SMG_Solo_Leagues AS l ON l.league_key = s.league_key AND l.league_name = @leagueName
			 WHERE s.league_key IN (SELECT league_key FROM dbo.SMG_fnGetSoloLeagues(@leagueName, s.season_key))
			 GROUP BY s.season_key
			 ORDER BY s.season_key DESC
		END
	END
	ELSE
	BEGIN
		RETURN	-- what other valid page types are there?
	END

    IF NOT EXISTS (SELECT 1 FROM @season_keys WHERE season_key = @seasonKey)
	BEGIN
		SELECT TOP 1 @seasonKey = season_key
		  FROM @season_keys
		 ORDER BY season_key DESC
	END

    -- league_names
    DECLARE @league_names TABLE (
	    display VARCHAR(100),
	    id VARCHAR(100)
	)

	INSERT INTO @league_names (id, display)
	SELECT id, display
	  FROM dbo.SMG_fnGetSoloLeagues(@leagueName, @seasonKey)


	IF (@leagueId IS NULL OR @leagueId NOT IN (SELECT id FROM @league_names))
	BEGIN
		IF (@leagueName = 'golf')
		BEGIN
			SET @leagueId = 'pga-tour'
		END
		ELSE IF (@leagueName IN ('motor', 'motor-sports'))
		BEGIN
			SET @leagueId = 'indycar'
		END
		ELSE
		BEGIN
			SELECT TOP 1 @leagueId = id FROM @league_names
		END
	END

	-- some pagetypes have an additional pageFilter
	DECLARE @filters XML
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)

	IF (@page = 'statistics')
	BEGIN

		IF @leagueName = 'tennis'
		BEGIN

			-- rankings fixture_key
			DECLARE @ranking_types TABLE (
				display VARCHAR(100),
				id VARCHAR(100)
			)
			INSERT INTO @ranking_types (id, display)
			SELECT fixture_key, UPPER(RIGHT(fixture_key, LEN(fixture_key) - PATINDEX('%-%', fixture_key)))
			  FROM dbo.SMG_Solo_Standings
			 WHERE league_key = @league_key AND season_key = @seasonKey
			 GROUP BY fixture_key
			 ORDER BY fixture_key

			IF (@pageFilter IS NULL OR @pageFilter NOT IN (SELECT id FROM @ranking_types))
			BEGIN
				SELECT TOP 1 @pageFilter = id FROM @ranking_types
			END

			SELECT @filters = (
				SELECT
				(
					SELECT id, display               
					  FROM @ranking_types
					   FOR XML RAW('filter'), TYPE
				)
				FOR XML RAW('filters'), TYPE
			)

		END

	END
	ELSE IF (@page = 'results')
	BEGIN
			
		-- event_names
		DECLARE @event_names TABLE (
			event_key VARCHAR(100),
			display VARCHAR(200),
			start_date_time DATETIME,
			id INT
		)

		INSERT INTO @event_names (display, event_key, start_date_time)
		SELECT e.event_name, e.event_key, e.start_date_time
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN dbo.SMG_Solo_Archive AS r ON e.event_key LIKE '%' + CAST(r.event_id AS VARCHAR)
		 WHERE e.season_key = @seasonKey AND e.league_key = @league_key
		 GROUP BY e.event_name, e.event_key, e.start_date_time

		IF (@leagueName = 'golf')
		BEGIN
			INSERT INTO @event_names (display, event_key, start_date_time)
			SELECT e.event_name, e.event_key, e.start_date_time
			  FROM dbo.SMG_Solo_Events AS e
			 INNER JOIN dbo.SMG_Solo_Results AS r ON r.event_key = e.event_key
			 WHERE e.season_key = @seasonKey AND e.league_key = @league_key AND r.[column] = 'score' AND r.value <> ''
			 GROUP BY e.event_name, e.event_key, e.start_date_time 
		END
		ELSE
		BEGIN
			INSERT INTO @event_names (display, event_key, start_date_time)
			SELECT e.event_name, e.event_key, e.start_date_time
			  FROM dbo.SMG_Solo_Events AS e
			 INNER JOIN dbo.SMG_Solo_Results AS r ON r.event_key = e.event_key
			 WHERE e.season_key = @seasonKey AND e.league_key = @league_key AND LOWER(e.event_status) <> 'postponed'
			 GROUP BY e.event_name, e.event_key, e.start_date_time 
		END

		UPDATE @event_names
		   SET display = CASE WHEN display LIKE '%at the%' THEN LEFT(display, CHARINDEX(' At the', display))
							  WHEN display LIKE '%benefiting%' THEN LEFT(display, CHARINDEX(' Benefiting', display))
							  WHEN display LIKE '%brought%' THEN LEFT(display, CHARINDEX(' Brought', display))
							  WHEN display LIKE '%in support%' THEN LEFT(display, CHARINDEX(' In Support', display))
							  WHEN display LIKE '%presented%' THEN LEFT(display, CHARINDEX(' Presented', display))
							  ELSE display
							  END

		UPDATE @event_names
		   SET id = dbo.SMG_fnEventId(event_key)

		IF (@pageFilter IS NULL OR @pageFilter NOT IN (SELECT id FROM @event_names))
		BEGIN
			SELECT TOP 1 @pageFilter = id
			  FROM @event_names
			 ORDER BY start_date_time DESC
		END

		SELECT @filters = (
			SELECT
			(
				SELECT id, display               
				  FROM @event_names
				 ORDER BY start_date_time DESC
				   FOR XML RAW('filter'), TYPE
			)
			FOR XML RAW('filters'), TYPE
		)

	END

	UPDATE @season_keys
	   SET season_display = CASE WHEN @leagueId IN ('pga-tour', 'european-tour') AND season_key > 2013
								 THEN CAST(season_key - 1 AS VARCHAR) + '-' + RIGHT(CAST(season_key AS VARCHAR), 2)
								 ELSE CAST(season_key AS VARCHAR)
								 END + ' Season'

    SELECT
    (
        SELECT season_key AS id, season_display AS display  
          FROM @season_keys
         ORDER BY season_key DESC
           FOR XML RAW('year'), TYPE
    ),
    (
        SELECT id, display
          FROM @league_names
		 ORDER BY display
           FOR XML RAW('league'), TYPE
    ),
    (
        SELECT @seasonKey AS [year],
               @leagueId AS league,
               @pageFilter AS filter
           FOR XML RAW('default'), TYPE
    ),
	(
		SELECT node.query('filter') FROM @filters.nodes('//filters') AS SMG(node)
	)
    FOR XML RAW('root'), TYPE

END

GO
