USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBrief_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBrief_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/03/2014
-- Description: get event brief
-- Update: 07/25/2014 - John Lin - lower case for team key
--         09/24/2014 - John Lin - add odds
--         09/26/2014 - John Lin - suppress data base on event status
--         10/02/2014 - ikenticus - adding MMA
--         10/09/2014 - John Lin - whitebg
--         11/25/2014 - John Lin - ncaa check if team last is null
--         12/29/2014 - ikenticus - (NOT IN) logic does not exclude from (CAST AS INT) conditional, refactoring "set correct week"
--         12/30/2014 - John Lin - refactor rank logic
--         03/03/2015 - ikenticus - SOC-180: Missing BSE Scores when NCAA @ Majors
--         04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
--         04/14/2015 - ikenticus: setting short = team_display for MLS
--         04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--         04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--         05/15/2015 - ikenticus: adjusting league_key for world cup
--         05/18/2015 - ikenticus: add flag folder for Women's World Cup
--         06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--         10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

	IF (@leagueName = 'mma')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSolo_MMA_XML @seasonKey, @eventId
		RETURN
	END

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/110/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/110/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @odds VARCHAR(100)
    DECLARE @detail_endpoint VARCHAR(100) = '/Event.svc/matchup/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_score INT
    DECLARE @away_winner VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_short VARCHAR(100)
    DECLARE @away_long VARCHAR(100)
    DECLARE @away_logo VARCHAR(100)
    DECLARE @away_record VARCHAR(100)
    DECLARE @away_rank VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_score INT
    DECLARE @home_winner VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_short VARCHAR(100)
    DECLARE @home_long VARCHAR(100)
    DECLARE @home_logo VARCHAR(100)
    DECLARE @home_record VARCHAR(100)
    DECLARE @home_rank VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status,
           @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
           @game_status = game_status, @away_key = away_team_key, @away_score = away_team_score,
           @home_key = home_team_key, @home_score = home_team_score, @week = [week], @odds = odds
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status,
			   @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
			   @game_status = game_status, @away_key = away_team_key, @away_score = away_team_score,
			   @home_key = home_team_key, @home_score = home_team_score, @week = [week], @odds = odds
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)


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

        SET @away_logo = @logo_prefix + 'ncaa' + @logo_folder + @away_abbr + @logo_suffix
        SET @home_logo = @logo_prefix + 'ncaa' + @logo_folder + @home_abbr + @logo_suffix


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

        IF (@leagueName IN ('natl', 'wwc'))
        BEGIN
			SET @away_logo = @logo_prefix + @flag_folder + @away_abbr + @logo_suffix
            SET @home_logo = @logo_prefix + @flag_folder + @home_abbr + @logo_suffix
        END
        ELSE IF (@leagueName IN ('epl', 'champions'))
		BEGIN
            SET @away_logo = @logo_prefix + 'euro' + @logo_folder + @away_abbr + @logo_suffix
            SET @home_logo = @logo_prefix + 'euro' + @logo_folder + @home_abbr + @logo_suffix
		END
		ELSE
		BEGIN
            SET @away_logo = @logo_prefix + @leagueName + @logo_folder + @away_abbr + @logo_suffix
            SET @home_logo = @logo_prefix + @leagueName + @logo_folder + @home_abbr + @logo_suffix
		END
    END

    SET @away_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @away_key, @event_key)
    SET @home_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @home_key, @event_key)

	-- HACK: pre-season NCAA at Majors (apparently, pre-season is not passed for daily)
    IF (@away_logo IS NULL) 
	BEGIN
		SELECT @away_short = team_first
		  FROM dbo.SMG_Teams
		 WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

		SELECT @away_abbr = team_abbreviation, @away_short = team_abbreviation,
		       @away_long = team_first, @away_key = team_key
		  FROM dbo.SMG_Teams
		 WHERE team_abbreviation IS NOT NULL AND team_abbreviation <> '' AND
		       (team_abbreviation = @away_short OR team_key LIKE '%' + RIGHT(@away_key, CHARINDEX('.t-', REVERSE(@away_key))))

           SET @away_logo = @logo_prefix + 'ncaa' + @logo_folder + @away_abbr + @logo_suffix
    END

    SELECT @ribbon = score
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key

    IF (@event_status = 'post-event')
    BEGIN
        IF (@away_score > @home_score)
        BEGIN
            SET @away_winner = '1'
            SET @home_winner = '0'
        END
        IF (@away_score < @home_score)
        BEGIN
            SET @away_winner = '0'
            SET @home_winner = '1'
        END
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



    SELECT
	(
        SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
               @start_date_time_UTC AS start_date_time_UTC, @game_status AS game_status, @ribbon AS ribbon, @odds AS odds,
               @detail_endpoint AS detail_endpoint, @leagueName AS league_name,
			   (
			       SELECT @away_score AS score,
			              @away_winner AS winner,
                          @away_abbr AS abbr,
                          @away_short AS short,
                          @away_long AS long,
                          @away_logo AS logo,
                          @away_record AS record,
                          @away_rank AS [rank]
                      FOR XML RAW('away'), TYPE                   
			   ),
			   ( 
			       SELECT @home_score AS score,
			              @home_winner AS winner,
                          @home_abbr AS abbr,
                          @home_short AS short,
                          @home_long AS long,
                          @home_logo AS logo,
                          @home_record AS record,
                          @home_rank AS [rank]
                      FOR XML RAW('home'), TYPE
               )
           FOR XML RAW('brief'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
