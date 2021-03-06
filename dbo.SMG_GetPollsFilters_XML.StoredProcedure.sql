USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPollsFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPollsFilters_XML]
	@leagueName VARCHAR(100),
	@fixtureKey VARCHAR(100) = NULL,
	@seasonKey INT = NULL,
	@week INT = NULL
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/19/2013
-- Description: get polls filters
-- Update:		09/30/2013 - ikenticus: using poll instead of category now that we refactored UX
--				10/21/2013 - ikenticus: adding poll_order to order the fixture_key dropdown
--				11/05/2013 - ikenticus: adding embargo based on publish_date_time
--				11/17/2013 - ikenticus - switched to leagueName
--              01/06/2014 - John Lin - update week display logic
--				02/11/2014 - ikenticus - adding sponsor logic
--				02/24/2014 - ikenticus - adding NCAAB/CWS leagueName
--				02/26/2014 - ikenticus - altering sponsor logic to encompass smg-usat across all polls, adding league filter
--				03/20/2014 - ikenticus - adding video display bit
--				03/25/2014 - ikenticus - correcting year dropdown and postseason for mbase, adding poll_date for better debugging
--				03/27/2014 - ikenticus - adding published_on for display_video check
--				05/20/2014 - ikenticus - limiting fixture_key to @poll_order
--				06/05/2014 - ikenticus - adding smg-usatfan logic
--				07/15/2014 - ikenticus - fixing addition of fixtureKey <> 'smg-usatfan' failing on NULL, adding redirect field to @leagues
--				07/28/2014 - ikenticus - fixing @poll_order across leagues, using data_front_attr for Fan Poll redirect/display, removing invalid team seasons
--				09/08/2014 - ikenticus: per JIRA SOC-92, moving BCS polls to bottom and displaying Historical
--				10/10/2014 - ikenticus: per JIRA SOC-114, commenting out Harris Polls as no longer produced
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    -- Unsupported league
    IF (@leagueName NOT IN (
		SELECT league_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 GROUP BY league_key
	))
    BEGIN
		-- Football should be default
		SET @leagueName = 'ncaaf'
    END

	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)


	-- leagues
    DECLARE @leagues TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100),
	    redirect VARCHAR(100),
		[order] INT
	)

	INSERT INTO @leagues (id, display, [order])
	VALUES	('ncaaf', 'NCAAF', 1),
			('ncaab', 'NCAAB', 2),
			('ncaaw', 'NCAAW', 3),
			('college/cws', 'NCAA Baseball', 4)

	IF (@leagueName NOT IN (SELECT(id) FROM @leagues))
	BEGIN
		SET @leagueName = (SELECT TOP 1 id FROM @leagues ORDER BY [order] DESC)
	END

--- Fixtures
	DECLARE @poll_order TABLE (
		fixture_key VARCHAR(100),
		display VARCHAR(100),
	    redirect VARCHAR(100),
		[order] INT
	)

	INSERT INTO @poll_order ([order], fixture_key, display)
	VALUES	(1, 'smg-usat', 'Coaches Poll'),
			(2, 'smg-usatfan', 'Fan Poll'),
			(3, 'poll-ap', 'AP Poll'),
			--(4, 'poll-harris', 'Harris Poll'),
			(5, 'ranking-bcs', 'Historical BCS Poll')

    IF (LOWER(@leagueName) <> 'ncaaf')
    BEGIN
        DELETE FROM @poll_order WHERE fixture_key IN ('ranking-bcs', 'poll-harris')
    END

    IF (LOWER(@leagueName) = 'college/cws')
    BEGIN
        DELETE FROM @poll_order WHERE fixture_key = 'poll-ap'
    END

    IF (@fixtureKey IS NULL OR @fixtureKey NOT IN (SELECT(fixture_key) FROM @poll_order))
    BEGIN
        SET @fixtureKey = 'smg-usat'
    END

--- Fan Poll Redirects
	DECLARE @redirect VARCHAR(100)

	SELECT @redirect = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE LOWER(league_name) = LOWER(@leagueName)
	   AND page_id = 'smg-usatfan' AND name = 'redirect'

	IF (@redirect IS NULL OR @redirect = '')
	BEGIN
		DELETE FROM @poll_order WHERE fixture_key = 'smg-usatfan'
	END
	BEGIN
		UPDATE @poll_order
		   SET redirect = @redirect
		 WHERE fixture_key = 'smg-usatfan'
	END

--- Sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE LOWER(league_name) = LOWER(@leagueName)
	   AND page_id = 'smg-usat' AND name = 'sponsor'

	IF (@sponsor IS NOT NULL)
	BEGIN
		UPDATE @poll_order
		   SET display = @sponsor + ' ' + display
		 WHERE fixture_key LIKE 'smg-usat%'
	END


--- Seasons
    DECLARE @seasons TABLE (
	    id INT,
	    display VARCHAR(100)
	)

	IF (@league_key = 'l.ncaa.org.mbase')
	BEGIN
		INSERT INTO @seasons (id, display)
		SELECT season_key, CAST(season_key AS VARCHAR)
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND fixture_key = @fixtureKey AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key
	END
	ELSE
	BEGIN
		INSERT INTO @seasons (id, display)
		SELECT season_key, CAST(season_key AS VARCHAR) + '-' + RIGHT(CAST(season_key + 1 AS VARCHAR), 2)
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND fixture_key = @fixtureKey AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key
	END

	DECLARE @team_seasons TABLE (season_key INT)
	 INSERT INTO @team_seasons
	 SELECT season_key FROM SMG_Teams WHERE league_key = @league_key GROUP BY season_key

	DELETE FROM @seasons WHERE id NOT IN (SELECT season_key FROM @team_seasons)

	IF (@seasonKey IS NULL OR @seasonKey > (SELECT MAX(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MAX(id) FROM @seasons)
	END

	IF (@seasonKey < (SELECT MIN(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MIN(id) FROM @seasons)
	END

	DECLARE @max_season INT
	SELECT @max_season = MAX(id) FROM @seasons


--- Weeks
    DECLARE @weeks TABLE (
	    id INT,
	    display VARCHAR(100),
		poll_date VARCHAR(100)
	)
/*	
	INSERT INTO @weeks
	SELECT
		week AS id,
		(CASE
			WHEN week = 1 THEN 'Preseason'
			WHEN week >= 16 AND @league_key = 'l.ncaa.org.mfoot' THEN 'Final Ranking'
			WHEN week = 20 AND @league_key <> 'l.ncaa.org.mfoot' THEN 'Postseason'
			WHEN week >= 21 AND @league_key <> 'l.ncaa.org.mfoot' THEN 'Postseason (Final)'
			ELSE 'Week ' + CAST(week AS VARCHAR(100)) END
		) AS display
	FROM SportsEditDB.dbo.SMG_Polls
	WHERE fixture_key = @fixtureKey
		AND league_key = @league_key
		AND season_key = @seasonKey
		AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
	GROUP BY season_key, week
*/

	INSERT INTO @weeks (id, display, poll_date)
	SELECT [week], 'Week ' + CAST([week] AS VARCHAR), poll_date
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = @fixtureKey		
	   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
	 GROUP BY season_key, [week], poll_date

    DECLARE @max_week INT
    
    SELECT TOP 1 @max_week = id
      FROM @weeks
     ORDER BY id DESC

    UPDATE @weeks
       SET display = 'Preseason'
     WHERE id = 1
         
    IF (@leagueName = 'ncaaf')
    BEGIN        
        UPDATE @weeks
           SET display = 'Final Ranking'
         WHERE id >= 16 AND id = @max_week
    END
    ELSE IF (@leagueName = 'cws')
    BEGIN        
        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id >= 15 AND id = @max_week
    END
    ELSE
    BEGIN
        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id = 20

        UPDATE @weeks
           SET display = 'Postseason (Final)'
         WHERE id >= 21 AND id = @max_week
    END

	IF (@week IS NULL OR @week NOT IN (SELECT id FROM @weeks))
	BEGIN
		SET @week = (SELECT MAX(id) FROM @weeks)
	END


--- Video
	DECLARE @poll_date VARCHAR(100)
	SELECT @poll_date = poll_date
	  FROM @weeks
	 WHERE @week = id

	DECLARE @video INT = 0
	IF (@seasonKey = @max_season AND @week = @max_week AND @fixtureKey = 'smg-usat')
	BEGIN
		SELECT @video = [value]
		  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
		 WHERE LOWER(league_name) = LOWER(@leagueName)
		   AND page_id = 'smg-usat' AND name = 'polls_video'
	END


--- XML Output
    SELECT @video AS display_video, @poll_date AS published_on,
    (
        SELECT id, display, redirect
		FROM @leagues
		ORDER BY [order] ASC
		FOR XML RAW('ncaa'), TYPE
    ),
    (
        SELECT fixture_key AS id, display, redirect
		FROM @poll_order
		ORDER BY [order] ASC
		FOR XML RAW('poll'), TYPE
    ),
    (
        SELECT id, display
		FROM @seasons
		ORDER BY id DESC
		FOR XML RAW('year'), TYPE
    ),
    (
        SELECT id, display, poll_date
		FROM @weeks
		ORDER BY id ASC
		FOR XML RAW('week'), TYPE
    ),
    (
		SELECT
			@leagueName AS [ncaa],
			@fixtureKey AS [poll],
			@seasonKey AS [year],
			@week AS [week]
		FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END




GO
