USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetBallotsFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetBallotsFilters_XML]
	@leagueName VARCHAR(100),
	@seasonKey INT = NULL,
	@week INT = NULL,
	@category VARCHAR(100) = NULL
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 11/22/2013
-- Description: get ballots categories
--              11/25/2013 - ikenticus - pluralize "school"
--              12/03/2013 - John Lin - default ncaaf to last week
--              12/04/2013 - John Lin - check current year
--              01/14/2014 - John Lin - add matrix view
--              01/20/2014 - John Lin - update week display logic
--				02/26/2014 - ikenticus - updated season logic for non-football
--				03/19/2014 - ikenticus - using last game of regular season for basketball
--				12/02/2014 - ikenticus - converting from Events_Warehouse to SMG_Schedules
--				01/13/2015 - ikenticus - @first_bowl_date logic forgot to use @seasonKey
--				03/11/2015 - ikenticus - purge all weeks after Postseason for Basketball
--				03/13/2015 - ikenticus - need to add magic numbers back for older Basketball seasons
--				03/31/2015 - ikenticus - ballots cutoff should be TOP1 ASC, not DESC, right?
--				04/08/2015 - ikenticus - ballots cutoff different between NCAAB and NCAAW
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
        RETURN
    END

	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

--- Seasons
    DECLARE @seasons TABLE (
	    id INT,
	    display VARCHAR(100)
	)
	INSERT INTO @seasons (id, display)
	SELECT season_key, CAST(season_key AS VARCHAR) + '-' + RIGHT(CAST(season_key + 1 AS VARCHAR), 2)
	  FROM SportsEditDB.dbo.SMG_Polls_Votes
	 WHERE league_key = @leagueName
	 GROUP BY season_key
	
	IF (@seasonKey IS NULL OR @seasonKey > (SELECT MAX(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MAX(id) FROM @seasons)
	END

	IF (@seasonKey < (SELECT MIN(id) FROM @seasons))
	BEGIN
		SET @seasonKey = (SELECT MIN(id) FROM @seasons)
	END


	DECLARE @last_game_date DATE
	DECLARE @last_poll_date DATE
	DECLARE @first_bowl_date DATE
	DECLARE @last_season_key INT
	DECLARE @postseason_week INT
	
	SELECT TOP 1 @last_season_key = id
	  FROM @seasons
	 ORDER BY id DESC

    IF (@leagueName = 'ncaaf')
    BEGIN
        -- ARMY NAVY game
		SELECT @last_game_date = CAST(ss.start_date_time_EST AS DATE)
		  FROM dbo.SMG_Schedules ss
		 INNER JOIN dbo.SMG_Teams a_st
		    ON a_st.team_key = ss.away_team_key AND a_st.season_key = ss.season_key AND a_st.team_abbreviation IN ('ARMY', 'NAVY')
		 INNER JOIN dbo.SMG_Teams h_st
		    ON h_st.team_key = ss.home_team_key AND h_st.season_key = ss.season_key AND h_st.team_abbreviation IN ('ARMY', 'NAVY')
		 WHERE ss.league_key = @league_key AND ss.season_key = @last_season_key

         -- last game of season
		SELECT TOP 1 @last_game_date = CAST(start_date_time_EST AS DATE)
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @league_key AND start_date_time_EST < @last_game_date
         ORDER BY start_date_time_EST DESC

        -- last poll entered
        SELECT TOP 1 @last_poll_date = poll_date
          FROM SportsEditDB.dbo.SMG_Polls_Votes
	     WHERE league_key = @leagueName AND season_key = @last_season_key AND [week] IS NOT NULL
	     ORDER BY poll_date DESC
	
        IF (@last_poll_date < @last_game_date)
        BEGIN
            DELETE @seasons
             WHERE id = @last_season_key
            
            IF (@last_season_key = @seasonKey)
            BEGIN 
                SET @seasonKey = @seasonKey - 1                        
            END
        END

        -- first bowl game of season
		SELECT TOP 1 @first_bowl_date = CAST(start_date_time_EST AS DATE)
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @league_key AND [week] = 'bowls' AND season_key = @seasonKey
         ORDER BY start_date_time_EST ASC

        -- last poll entered before bowls
        SELECT TOP 1 @week = [week]
          FROM SportsEditDB.dbo.SMG_Polls_Votes
         WHERE league_key = @leagueName AND season_key = @seasonKey AND poll_date < @first_bowl_date AND [week] IS NOT NULL
         ORDER BY [week] DESC	        
    END
    ELSE
    BEGIN

        -- last game of regular season
		SELECT TOP 1 @last_game_date = start_date_time_EST
		  FROM SMG_Schedules
		 WHERE league_key = @league_key AND sub_season_type = 'season-regular'
		 ORDER BY start_date_time_EST DESC

        -- last poll entered
        SELECT TOP 1 @last_poll_date = poll_date
          FROM SportsEditDB.dbo.SMG_Polls_Votes
	     WHERE league_key = @leagueName AND season_key = @last_season_key AND [week] IS NOT NULL
	     ORDER BY poll_date DESC
	
        IF (@last_poll_date < @last_game_date)
        BEGIN
            DELETE @seasons
             WHERE id = @last_season_key
            
            IF (@last_season_key = @seasonKey)
            BEGIN 
                SET @seasonKey = @seasonKey - 1

				-- reacquire last game of regular season
				SELECT TOP 1 @last_game_date = start_date_time_EST
				  FROM SMG_Schedules
				 WHERE league_key = @league_key AND sub_season_type = 'season-regular' AND season_key = @seasonKey
				 ORDER BY start_date_time_EST DESC                 
            END
        END
	END

--- Weeks
    DECLARE @weeks TABLE (
	    id INT,
	    display VARCHAR(100)
	)

	INSERT INTO @weeks (id, display)
	SELECT [week], 'Week ' + CAST([week] AS VARCHAR)
	  FROM SportsEditDB.dbo.SMG_Polls_Votes
	 WHERE league_key = @leagueName AND season_key = @seasonKey AND week IS NOT NULL
	 GROUP BY season_key, week

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
    ELSE
    BEGIN
		-- Leaving magic numbers for years older than exists in SMG_Schedules
        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id = 20

        DELETE @weeks
         WHERE id >= 21

		IF (@leagueName = 'ncaab')
		BEGIN
			-- Since games play last-minute on Selection Sunday: poll_date >= last_game_date
			SELECT TOP 1 @postseason_week = week
			  FROM SportsEditDB.dbo.SMG_Polls_Votes
			 WHERE league_key = @leagueName AND season_key = @seasonKey AND week IS NOT NULL AND poll_date >= @last_game_date
			 ORDER BY poll_date ASC
		END
		ELSE
		BEGIN
			-- Since last games are less than a week before Selection Monday: poll_date > last_game_date
			SELECT TOP 1 @postseason_week = week
			  FROM SportsEditDB.dbo.SMG_Polls_Votes
			 WHERE league_key = @leagueName AND season_key = @seasonKey AND week IS NOT NULL AND poll_date > @last_game_date
			 ORDER BY poll_date ASC
		END

        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id = @postseason_week

        DELETE @weeks
         WHERE id > @postseason_week
    END

	IF (@week IS NULL OR @week NOT IN (SELECT id FROM @weeks))
	BEGIN
		SET @week = (SELECT MAX(id) FROM @weeks)
	END


--- Categories
    DECLARE @categories TABLE (
	    id VARCHAR(100),
		[order] INT,
	    display VARCHAR(100)
	)

	INSERT INTO @categories ([order], id, display)
	VALUES
		(1, 'coaches', 'Coaches Rank'),
		(2, 'schools', 'Schools Rank')

    IF (@leagueName = 'ncaaf')
    BEGIN
		INSERT INTO @categories ([order], id, display)
		VALUES (3, 'matrix', 'Matrix View')
	END

	IF (@category IS NULL OR @category NOT IN (SELECT id FROM @categories))
	BEGIN
		SET @category = (SELECT TOP 1 id FROM @categories ORDER BY [order] ASC)
	END


	-- Generate XML output
    SELECT
    (
        SELECT id, display
		FROM @categories
		ORDER BY [order] ASC
		FOR XML RAW('category'), TYPE
    ),
    (
        SELECT id, display
		FROM @seasons
		ORDER BY id DESC
		FOR XML RAW('year'), TYPE
    ),
    (
        SELECT id, display
		FROM @weeks
		ORDER BY id ASC
		FOR XML RAW('week'), TYPE
    ),
    (
		SELECT
			@category AS [category],
			@seasonKey AS [year],
			@week AS [week]
		FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END




GO
