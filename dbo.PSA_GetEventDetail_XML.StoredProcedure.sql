USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventDetail_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventDetail_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/27/2014
-- Description: get event detail
-- Update:		07/09/2014 - ikenticus - adjusting gallery start/end times
--              07/25/2014 - John Lin - lower case for team key
--              08/19/2014 - ikenticus - add sub_season_key for linescore variations
--              09/09/2014 - ikenticus - switching NCAA to whitebg logos
-- 				09/19/2014 - ikenticus: adding EPL/Champions
--              09/26/2014 - John Lin - suppress data base on event status
-- 				10/02/2014 - ikenticus - adding MMA
--              10/09/2014 - John Lin - whitebg
-- 				10/16/2014 - ikenticus - suppress logo and record when TBA team
--				10/17/2014 - ikenticus - added names for TBA
--              11/25/2014 - John Lin - ncaa check if team last is null
--              01/14/2014 - John Lin - new logic to ncaa ran
--				03/03/2015 - ikenticus - SJ-1399: NCAA @ Majors
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
--				04/14/2015 - ikenticus: setting short = team_display for MLS
--              04/22/2015 - John Lin - use mobile ribbon
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--              05/15/2015 - ikenticus: adjusting league_key for world cup
--         		05/18/2015 - ikenticus: add flag folder for Women's World Cup
--				05/21/2015 - ikenticus - utilize winner_team_key if available
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--				07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--              07/10/2015 - John Lin - STATS team records
--              07/28/2015 - John Lin - MLS All Stars
--				10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

	IF (@leagueName = 'mma')
	BEGIN
		EXEC dbo.PSA_GetEventDetailSolo_MMA_XML @seasonKey, @eventId
		RETURN
	END

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
	DECLARE @sub_season_type VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @winner_key VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @odds VARCHAR(100)
    DECLARE @level_name VARCHAR(100)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_score INT
    DECLARE @away_winner VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_short VARCHAR(100)
    DECLARE @away_long VARCHAR(100)
    DECLARE @away_logo VARCHAR(100)
    DECLARE @away_rank VARCHAR(100)
    DECLARE @away_record VARCHAR(100)
    DECLARE @home_pitcher VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_score INT
    DECLARE @home_winner VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_short VARCHAR(100)
    DECLARE @home_long VARCHAR(100)
    DECLARE @home_logo VARCHAR(100)
    DECLARE @home_rank VARCHAR(100)
    DECLARE @home_record VARCHAR(100)
    DECLARE @away_pitcher VARCHAR(100) 

    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @sub_season_type = sub_season_type,
           @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST, @level_name = level_name,
           @odds = odds, @game_status = game_status, @away_key = away_team_key, @away_score = away_team_score,
           @home_key = home_team_key, @home_score = home_team_score, @week = [week], @winner_key = winner_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @sub_season_type = sub_season_type,
			   @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
			   @odds = odds, @game_status = game_status, @away_key = away_team_key, @away_score = away_team_score,
			   @home_key = home_team_key, @home_score = home_team_score, @week = [week], @winner_key = winner_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)
    SET @away_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @away_key, @event_key)
    SET @home_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @home_key, @event_key)
           
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_abbr = team_abbreviation, @away_short = team_first, @away_long = CASE
                                                                                          WHEN team_last IS NULL THEN team_first
                                                                                          ELSE team_first + ' ' + team_last
                                                                                      END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_abbr = team_abbreviation, @home_short = team_first, @home_long = CASE
                                                                                          WHEN team_last IS NULL THEN team_first
                                                                                          ELSE team_first + ' ' + team_last
                                                                                      END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key

        -- RANK
        DECLARE @poll_week INT
    
        IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
		                                       FROM SportsEditDB.dbo.SMG_Polls
				                              WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND [week] = @week))
        BEGIN
	    	SET @poll_week = CAST(@week AS INT)
    	END
	    ELSE
    	BEGIN             
	    	SELECT TOP 1 @poll_week = [week]
		      FROM SportsEditDB.dbo.SMG_Polls
    		 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat'
	    	 ORDER BY [week] DESC
    	END

	    SELECT @away_rank = ranking
    	  FROM SportsEditDB.dbo.SMG_Polls
	     WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
		       team_key = @away_abbr AND [week] = @poll_week
              
        SELECT @home_rank = ranking
    	  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
    		   team_key = @home_abbr AND [week] = @poll_week

        
        IF (@leagueName IN ('ncaab', 'ncaaw') AND @week IS NOT NULL AND @week = 'ncaa')
        BEGIN
            SELECT @away_rank = seed
              FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
             WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

            SELECT @home_rank = seed
              FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
             WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
        END
    END
    ELSE
    BEGIN
        IF (@leagueName IN ('natl', 'wwc', 'epl', 'champions'))
        BEGIN
			SELECT @away_abbr = team_abbreviation, @away_short = team_first, @away_long = team_first
			  FROM dbo.SMG_Teams
			 WHERE season_key = @seasonKey AND team_key = @away_key

			SELECT @home_abbr = team_abbreviation, @home_short = team_first, @home_long = team_first
			  FROM dbo.SMG_Teams
			 WHERE season_key = @seasonKey AND team_key = @home_key
        END
		ELSE
		BEGIN
			SELECT @away_abbr = team_abbreviation, @away_short = team_display, @away_long = team_first + ' ' + team_last
			  FROM dbo.SMG_Teams
			 WHERE season_key = @seasonKey AND team_key = @away_key

			SELECT @home_abbr = team_abbreviation, @home_short = team_display, @home_long = team_first + ' ' + team_last
			  FROM dbo.SMG_Teams
			 WHERE season_key = @seasonKey AND team_key = @home_key
		END
    END

    SET @away_logo = dbo.SMG_fnTeamLogo(@leagueName, @away_abbr, '110')
    SET @home_logo = dbo.SMG_fnTeamLogo(@leagueName, @home_abbr, '110')

	IF (@leagueName = 'mls' AND @level_name = 'exhibition')
	BEGIN
		SET @away_logo = dbo.SMG_fnTeamLogo('euro', @away_abbr, '110')
	END

	-- HACK: pre-season NCAA at Majors (apparently, pre-season is not passed for daily)
    IF (@away_logo IS NULL) 
	BEGIN
		SELECT @away_short = team_first
		  FROM dbo.SMG_Teams
		 WHERE season_key = @seasonKey AND team_key = @away_key

		SELECT @away_abbr = team_abbreviation, @away_short = team_abbreviation,
		       @away_long = team_first, @away_key = team_key
		  FROM dbo.SMG_Teams
		 WHERE team_abbreviation IS NOT NULL AND team_abbreviation <> '' AND
		       (team_abbreviation = @away_short OR team_key LIKE '%' + RIGHT(@away_key, CHARINDEX('.t-', REVERSE(@away_key))))

           SET @away_logo = dbo.SMG_fnTeamLogo('ncaa', @away_abbr, '110')
    END

    SELECT @ribbon = mobile
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key

    IF (@event_status = 'post-event')
    BEGIN
        IF (@away_score > @home_score)
        BEGIN
            SET @away_winner = '1'
            SET @home_winner = '0'
        END
        ELSE IF (@away_score < @home_score)
        BEGIN
            SET @away_winner = '0'
            SET @home_winner = '1'
        END
		ELSE IF (@away_key = @winner_key)
		BEGIN
            SET @away_winner = '1'
            SET @home_winner = '0'
		END
		ELSE IF (@home_key = @winner_key)
        BEGIN
            SET @away_winner = '0'
            SET @home_winner = '1'
        END
    END

    -- PITCHER    
    IF (@event_status = 'pre-event' AND @leagueName = 'mlb')
    BEGIN    
        SELECT @away_pitcher = LEFT(sp.first_name, 1) + '. ' + sp.last_name
          FROM dbo.SMG_Players sp
         INNER JOIN dbo.SMG_Transient st
            ON st.team_key = @away_key AND st.event_key = @event_key AND st.player_key = sp.player_key

        SELECT @home_pitcher = LEFT(sp.first_name, 1) + '. ' + sp.last_name
          FROM dbo.SMG_Players sp
         INNER JOIN dbo.SMG_Transient st
            ON st.team_key = @home_key AND st.event_key = @event_key AND st.player_key = sp.player_key
    END

    -- suppress
    IF (@event_status NOT IN ('pre-event', 'postponed', 'canceled'))
    BEGIN
        SET @odds = ''
    END

    IF (@event_status NOT IN ('pre-event', 'mid-event', 'intermission', 'weather-delay'))
    BEGIN
        SET @tv_coverage = ''
    END

    IF (LEN(@tv_coverage) > 12 AND CHARINDEX(',', @tv_coverage) > 0)
    BEGIN
       SET @tv_coverage = SUBSTRING(@tv_coverage, 1, CHARINDEX(',', @tv_coverage) - 1)
    END

	IF (@away_abbr = 'TBA')
	BEGIN
		SET @away_record = ''
		SET @away_logo = ''
		SET @away_short = 'TBA'
		SET @away_long = 'To Be Announced'
	END

	IF (@home_abbr = 'TBA')
	BEGIN
		SET @home_record = ''
		SET @home_record = ''
		SET @home_short = 'TBA'
		SET @home_long = 'To Be Announced'
	END


    SELECT
	(
        SELECT @event_status AS event_status, @sub_season_type AS sub_season_type,
               @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
               @start_date_time_UTC AS start_date_time_UTC, @odds AS odds, @game_status AS game_status, @ribbon AS ribbon,
			   (
			       SELECT @away_score AS score,
			              @away_winner AS winner,
                          @away_abbr AS abbr,
                          @away_short AS short,
                          @away_long AS long,
                          @away_logo AS logo,
                          @away_rank AS [rank],
                          @away_record AS record,
                          @away_pitcher AS pitcher
                      FOR XML RAW('away'), TYPE                   
			   ),
			   ( 
			       SELECT @home_score AS score,
			              @home_winner AS winner,
                          @home_abbr AS abbr,
                          @home_short AS short,
                          @home_long AS long,
                          @home_logo AS logo,
                          @home_rank AS [rank],
                          @home_record AS record,
                          @home_pitcher AS pitcher
                      FOR XML RAW('home'), TYPE
               )
           FOR XML RAW('detail'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
