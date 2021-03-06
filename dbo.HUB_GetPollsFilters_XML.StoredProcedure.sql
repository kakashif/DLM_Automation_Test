USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetPollsFilters_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetPollsFilters_XML]
	@leagueName VARCHAR(100),
	@fixtureKey VARCHAR(100),
	@seasonKey INT,
	@week INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 06/13/2014
-- Description: get polls filters, clone of SMG_GetPollsFilters
--				adding Fan Poll as part of the full list, utilizing same Coaches Poll sponsor
-- Update:		07/10/2014 - ikenticus - removing publish_date embargo from Fan Poll
--				07/14/2014 - ikenticus - adding end_date_time for Fan Poll
--				07/23/2014 - ikenticus - fixing default fixtureKey/seasonKey/week logic
--				07/24/2014 - ikenticus - excluding NULL week from @weeks retrieval logic
--				07/28/2014 - ikenticus - fixing @poll_order across leagues, removing invalid team seasons
--				07/30/2014 - ikenticus - removing fan poll from non-ncaaf leagues
--				07/07/2015 - ikenticus - apparently FanPoll uses this, switching to new SMG_Polls* logic
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
		SET @leagueName = 'ncaaf'
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	-- leagues
    DECLARE @leagues TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100),
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
		[order] INT
	)
	INSERT INTO @poll_order ([order], fixture_key, display)
	VALUES	(1, 'smg-usat', 'Coaches Poll'),
			(2, 'poll-ap', 'AP Poll'),
			(3, 'ranking-bcs', 'BCS Poll'),
			(4, 'poll-harris', 'Harris Poll'),
			(5, 'smg-usatfan', 'Fan Poll')

    IF (LOWER(@leagueName) <> 'ncaaf')
    BEGIN
        DELETE FROM @poll_order WHERE fixture_key IN ('ranking-bcs', 'poll-harris', 'smg-usatfan')
    END

    IF (LOWER(@leagueName) = 'cws')
    BEGIN
        DELETE FROM @poll_order WHERE fixture_key = 'poll-ap'
    END

    IF (@fixtureKey IS NULL OR @fixtureKey NOT IN (SELECT(fixture_key) FROM @poll_order))
    BEGIN
        SET @fixtureKey = 'smg-usat'
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

	IF (@leagueName = 'cws')
	BEGIN
		INSERT INTO @seasons
		SELECT season_key AS id,
			   CONVERT(VARCHAR(100), season_key) AS display
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixtureKey AND league_key = @leagueName
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key
	END
	ELSE
	BEGIN
		IF (@fixtureKey = 'smg-usatfan')
		BEGIN
			INSERT INTO @seasons
			SELECT season_key AS id,
				   (CONVERT(VARCHAR(100), season_key) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2)) AS display
			  FROM SportsEditDB.dbo.SMG_Polls
			 WHERE fixture_key = @fixtureKey AND league_key = @leagueName
			 GROUP BY season_key
		END
		ELSE
		BEGIN
			INSERT INTO @seasons
			SELECT season_key AS id,
				   (CONVERT(VARCHAR(100), season_key) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2)) AS display
			  FROM SportsEditDB.dbo.SMG_Polls
			 WHERE fixture_key = @fixtureKey AND league_key = @leagueName
			   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
			 GROUP BY season_key
		END
	END

	DECLARE @team_seasons TABLE (
		season_key INT
	)

	INSERT INTO @team_seasons (season_key)
	SELECT season_key
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key
	 GROUP BY season_key

	DELETE FROM @seasons WHERE id NOT IN (SELECT season_key FROM @team_seasons)

	IF (@seasonKey IS NULL OR @seasonKey > (SELECT MAX(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MAX(id) FROM @seasons)
	END

	IF (@seasonKey < (SELECT MIN(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MIN(id) FROM @seasons)
	END

	IF (@seasonKey > YEAR(GETDATE()))
	BEGIN
		SET @seasonKey = YEAR(GETDATE())
	END

	DECLARE @max_season INT
	SELECT @max_season = MAX(id) FROM @seasons


--- Weeks
    DECLARE @weeks TABLE (
	    id INT,
	    display VARCHAR(100),
		poll_date VARCHAR(100)
	)

	INSERT INTO @weeks (id, display)
	SELECT week, CASE
						WHEN week = 1 THEN 'Preseason'
						WHEN week >= 16 AND @leagueName = 'ncaaf' THEN 'Final Ranking'
						WHEN week = 20 AND @leagueName <> 'ncaaf' THEN 'Postseason'
						WHEN week >= 21 AND @leagueName <> 'ncaaf' THEN 'Postseason (Final)'
						ELSE 'Week ' + CAST(week AS VARCHAR(100))
					END
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE fixture_key = @fixtureKey AND league_key = @leagueName AND season_key = @seasonKey
	   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
	 GROUP BY season_key, week

	IF (@fixtureKey = 'smg-usatfan')
	BEGIN
		INSERT INTO @weeks (id, display, poll_date)
		SELECT [week], 'Week ' + CAST([week] AS VARCHAR), poll_date
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixtureKey AND league_key = @leagueName AND season_key = @seasonKey AND week IS NOT NULL
		 GROUP BY season_key, [week], poll_date	
	END
	ELSE
	BEGIN
		INSERT INTO @weeks (id, display, poll_date)
		SELECT [week], 'Week ' + CAST([week] AS VARCHAR), poll_date
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixtureKey AND league_key = @leagueName AND season_key = @seasonKey
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key, [week], poll_date
	END

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

	IF (@week IS NULL)
	BEGIN
		SET @week = 1
	END

	DECLARE @end_date_time DATETIME
	IF (@fixtureKey = 'smg-usatfan')
	BEGIN
		SELECT TOP 1 @end_date_time = publish_date_time
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND fixture_key = @fixtureKey AND season_key = @seasonKey AND week = @week
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
			ISNULL(@end_date_time, DATEADD(DD, 5, GETDATE())) AS end_date_time,
			--'2014-07-24T15:00:00.0' AS end_date_time,
    (
        SELECT id, display
		  FROM @leagues
		 ORDER BY [order] ASC
		   FOR XML RAW('ncaa'), TYPE
    ),
    (
        SELECT fixture_key AS id, display
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
		SELECT @leagueName AS [ncaa], @fixtureKey AS [poll], @seasonKey AS [year], @week AS [week]
		   FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE

END


GO
