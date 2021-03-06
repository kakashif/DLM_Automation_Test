USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Matchup_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_Matchup_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100)
AS
--=============================================
-- Author:	    John Lin
-- Create date: 10/29/2013
-- Description: get team matchup for desktop
-- Update: 07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--         09/16/2015 - John Lin - SDI migration
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @winner_key VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @poll_date DATE
    DECLARE @link_boxscore VARCHAR(MAX)
    DECLARE @link_recap    VARCHAR(100)

    
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_name VARCHAR(100)
    DECLARE @away_rgb VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_logo VARCHAR(100)
    DECLARE @away_slug VARCHAR(100)
    DECLARE @away_rank VARCHAR(100) = ''
    DECLARE @away_score VARCHAR(100)
    DECLARE @away_winner VARCHAR(100)
    DECLARE @away_record VARCHAR(100)
    DECLARE @away_link VARCHAR(100)

    DECLARE @home_key VARCHAR(100)
    DECLARE @home_name VARCHAR(100)
    DECLARE @home_rgb VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_logo VARCHAR(100)
    DECLARE @home_slug VARCHAR(100)
    DECLARE @home_rank VARCHAR(100) = ''
    DECLARE @home_score VARCHAR(100)
    DECLARE @home_winner VARCHAR(100)
    DECLARE @home_record VARCHAR(100)
    DECLARE @home_link VARCHAR(100)

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    SELECT @season_key = team_season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'scores'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

    IF (CAST(GETDATE() AS TIME) > '11:00:00')
    BEGIN    
        SELECT TOP 1 @sub_season_type = sub_season_type, @week = [week], @event_key = event_key, @event_status = event_status,
                     @start_date_time_EST = start_date_time_EST, @game_status = game_status, @winner_key = winner_team_key,
                     @away_key = away_team_key, @away_score = away_team_score, @home_key = home_team_key, @home_score = home_team_score                     
	      FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND start_date_time_EST >  CONVERT(DATE, GETDATE())
         ORDER BY start_date_time_EST ASC
    END

    IF (@event_key IS NULL)
    BEGIN
        SELECT TOP 1 @sub_season_type = sub_season_type, @week = [week], @event_key = event_key, @event_status = event_status,
                     @start_date_time_EST = start_date_time_EST, @game_status = game_status, @winner_key = winner_team_key,
                     @away_key = away_team_key, @away_score = away_team_score, @home_key = home_team_key, @home_score = home_team_score                     
	      FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND start_date_time_EST <  CONVERT(DATE, GETDATE())
         ORDER BY start_date_time_EST DESC
    END

    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        SELECT @away_name = team_first, @away_abbr = team_abbreviation, @away_slug = team_slug, @away_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = @away_key	 

        SELECT @home_name = team_first, @home_abbr = team_abbreviation, @home_slug = team_slug, @home_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_name = team_last, @away_abbr = team_abbreviation, @away_slug = team_slug, @away_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = @away_key	 

        SELECT @home_name = team_last, @home_abbr = team_abbreviation, @home_slug = team_slug, @home_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = @home_key
    END

    SET @away_link = '/sports/' + @leagueName + '/' + @away_slug + '/'
    SET @home_link = '/sports/' + @leagueName + '/' + @home_slug + '/'

    -- logo
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SET @away_logo = @logo_prefix + 'ncaa' + @logo_folder + '110/' + @away_abbr + @logo_suffix
        SET @home_logo = @logo_prefix + 'ncaa' + @logo_folder + '110/' + @home_abbr + @logo_suffix
    END
    ELSE
    BEGIN
        -- CON.png hack
        SET @away_logo = @logo_prefix + @leagueName + @logo_folder + '110/' +
                         CASE
                             WHEN @leagueName = 'wnba' AND @away_abbr = 'CON' THEN 'CON_'
                             ELSE @away_abbr
                         END + @logo_suffix
        SET @home_logo = @logo_prefix + @leagueName + @logo_folder + '110/' +
                         CASE
                             WHEN @leagueName = 'wnba' AND @home_abbr = 'CON' THEN 'CON_'
                             ELSE @home_abbr
                         END + @logo_suffix
    END

    SET @away_record = '(' + SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @season_key, @away_key, @event_key) + ')'
    SET @home_record = '(' + SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @season_key, @home_key, @event_key) + ')'
       
    -- RIBBON
    SELECT @ribbon = score
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key

    IF (@ribbon IS NULL)
    BEGIN
        IF (@leagueName IN ('nfl', 'ncaaf') AND ISNUMERIC(@week) = 1)
        BEGIN
            IF (@sub_season_type = 'pre-season')
            BEGIN
                SET @ribbon = 'Preseason - Week ' + @week
            END
            ELSE
            BEGIN
                SET @ribbon = 'Week ' + @week
            END
        END
    END
    
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        SELECT TOP 1 @poll_date = poll_date
          FROM SportsEditDB.dbo.SMG_Polls
          WHERE league_key = @leagueName AND fixture_key = 'smg-usat' AND poll_date < @start_date_time_EST
          ORDER BY poll_date DESC

        SELECT @away_rank = ranking
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = @leagueName AND poll_date = @poll_date AND fixture_key = 'smg-usat' AND team_key = @away_abbr

        SELECT @home_rank = ranking
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = @leagueName AND poll_date = @poll_date AND fixture_key = 'smg-usat' AND team_key = @home_abbr
    END



    -- switch between event status
    IF (@event_status = 'pre-event')
    BEGIN
        SET @away_score = NULL
        SET @home_score = NULL
    END
    ELSE
    BEGIN
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
    END
    
--    IF (@event_status = 'pre-event')
--    BEGIN
        DECLARE @matchup TABLE
        (
		    id INT IDENTITY(1, 1) PRIMARY KEY,
    		name VARCHAR(100),
	    	[column] VARCHAR(100),
		    away_value VARCHAR(100),
    		away_percentage VARCHAR(100),
	    	home_value VARCHAR(100),
		    home_percentage VARCHAR(100)
        )
        IF (@leagueName = 'mlb')
        BEGIN        
            INSERT INTO @matchup (name, [column])
            VALUES ('BATTING AVERAGE', 'average'),
                   ('RUNS SCORED PER GAME', 'runs-scored-per-game'),
                   ('EARNED RUN AVERAGE', 'era'),
                   ('RUNS ALLOWED PER GAME', 'runs-allowed-per-game')
                   
                   
        END
/*
        ELSE IF (@leagueName = 'mls')
        BEGIN
            INSERT INTO @columns ([column])
            VALUES ('goals-per-game'), ('shots-allowed-per-game'), ('power-play-percentage')
        END
*/
        ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
        BEGIN
            IF (@leagueName IN ('nba', 'wnba'))
            BEGIN
                INSERT INTO @matchup (name, [column])
                VALUES ('POINTS PER GAME', 'points-scored-for-per-game'),
                       ('FIELD GOAL %', 'field-goals-percentage'),
                       ('REBOUNDS PER GAME', 'rebounds-per-game'),
                       ('ASSISTS PER GAME', 'assists-per-game'),
                       ('STEALS PER GAME', 'steals-per-game'), 
                       ('TURNOVERS PER GAME', 'turnovers-total-per-game'),
                       ('BLOCKS PER GAME', 'blocks-per-game')
            END
            ELSE
            BEGIN
                INSERT INTO @matchup (name, [column])
                VALUES ('POINTS PER GAME', 'points-scored-total-per-game'),
                       ('FIELD GOAL %', 'field-goals-percentage'),
                       ('REBOUNDS PER GAME', 'rebounds-per-game'),
                       ('ASSISTS PER GAME', 'assists-total-per-game'),
                       ('STEALS PER GAME', 'steals-total-per-game'), 
                       ('TURNOVERS PER GAME', 'turnovers-total-per-game'),
                       ('BLOCKS PER GAME', 'blocks-total-per-game')
            END
        END
        ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
        BEGIN
            INSERT INTO @matchup (name, [column])
            VALUES ('POINTS', 'points-per-game'),
                   ('POINTS ALLOWED', 'points-against-per-game'),
                   ('YARDS', 'total-yards-per-game'),
                   ('YARDS ALLOWED', 'total-yards-against-per-game'),
                   ('PASSING YARDS', 'passing-net-yards-per-game'),
                   ('PASSING YARDS ALLOWED', 'passing-net-yards-against-per-game'),
                   ('RUSHING YARDS', 'rushing-net-yards-per-game'),
                   ('RUSHING YARDS ALLOWED', 'rushing-net-yards-against-per-game')
        END
        ELSE IF (@leagueName = 'nhl')
        BEGIN
            INSERT INTO @matchup (name, [column])
            VALUES ('GOALS', 'goals-per-game'),
                   ('GOALS ALLOWED', 'goals-allowed-per-game'),
                   ('SHOTS', 'shots-per-game'),
                   ('SHOTS ALLOWED', 'shots-allowed-per-game'),
                   ('PENALTY MINUTES', 'penalty-minutes-per-game')
        END
       
        UPDATE m
           SET m.away_value = st.value
          FROM @matchup m
         INNER JOIN SportsEditDB.dbo.SMG_Statistics st
	        ON st.league_key = @league_key AND st.season_key = @season_key AND st.sub_season_type = @sub_season_type AND
    	       st.team_key = @away_key AND st.[column] = m.[column] AND st.category = 'feed' AND st.player_key = 'team'
	
        UPDATE m
           SET m.home_value = st.value
          FROM @matchup m
         INNER JOIN SportsEditDB.dbo.SMG_Statistics st
	        ON st.league_key = @league_key AND st.season_key = @season_key AND st.sub_season_type = @sub_season_type AND
	           st.team_key = @home_key AND st.[column] = m.[column] AND st.category = 'feed' AND st.player_key = 'team'

        -- standings
        UPDATE m
           SET m.away_value = ss.value
          FROM @matchup m
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
	        ON ss.season_key = @season_key AND ss.team_key = @away_key AND ss.[column] = m.[column]
    	 WHERE m.[column] IN ('@season_key-scored-for', 'points-scored-for-per-game', 'points-scored-against', 'points-scored-against-per-game')

        UPDATE m
           SET m.home_value = ss.value
          FROM @matchup m
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
	        ON ss.season_key = @season_key AND ss.team_key = @home_key AND ss.[column] = m.[column]
    	 WHERE m.[column] IN ('points-scored-for', 'points-scored-for-per-game', 'points-scored-against', 'points-scored-against-per-game')
	   

        UPDATE @matchup
           SET away_percentage = ROUND(CAST(away_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)

        UPDATE @matchup
           SET home_percentage = ROUND(CAST(home_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)


		-- some SDI formatting
		UPDATE @matchup
		   SET away_value = REPLACE(CAST(CAST(away_value AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
               home_value = REPLACE(CAST(CAST(home_value AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')
		 WHERE name = 'BATTING AVERAGE'

		UPDATE @matchup
		   SET away_value = CAST(CAST(away_value AS DECIMAL(5,2)) AS VARCHAR),
               home_value = CAST(CAST(home_value AS DECIMAL(5,2)) AS VARCHAR)
		 WHERE name = 'EARNED RUN AVERAGE'
               

    	-- Remove the rows where the matchup contains no data
	    DELETE FROM @matchup
    	 WHERE away_value IS NULL AND home_value IS NULL


        SELECT
        (
            SELECT @game_status AS game_status, @start_date_time_EST AS start_date_time_EST, @ribbon AS ribbon,
                   (
                       SELECT @away_name AS name,  @away_logo AS logo, @away_rank AS [rank], @away_rgb AS rgb,
                              @away_record AS record, @away_score AS score, @away_winner AS winner
                          FOR XML RAW('away_team'), TYPE
                   ),
                   (
                       SELECT @home_name AS name,  @home_logo AS logo, @home_rank AS [rank], @home_rgb AS rgb,
                              @home_record AS record, @home_score AS score, @home_winner AS winner
                          FOR XML RAW('home_team'), TYPE
                   )
               FOR XML RAW('event'), TYPE
        ),
	    (
	        SELECT @away_rgb AS away_rgb, @home_rgb AS home_rgb, 
                   (
                       SELECT name, away_value, away_percentage, home_value, home_percentage
                         FROM @matchup
                        ORDER BY id ASC
                      FOR XML RAW('stats'), TYPE
                   )
               FOR XML RAW('matchup'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    
        RETURN
--    END

/*
    IF (@away_key = @winner_key)
    BEGIN
       SET @away_winner = '1'
       SET @home_winner = '0'
    END
     
    IF (@home_key = @winner_key)
    BEGIN
       SET @home_winner = '1'
       SET @away_winner = '0'
    END

    IF (@leagueName IN ('mls'))
    BEGIN
        UPDATE @events
           SET link_boxscore = '/sports/soccer/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET link_recap = '/sports/soccer/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    ELSE
    BEGIN
        UPDATE @events
           SET link_boxscore = '/sports/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET link_recap = '/sports/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    
    -- SEC HACK
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
         UPDATE @events
           SET link_boxscore = link_boxscore + 'top25/',
               link_preview = link_preview + 'top25/',
               link_recap = link_recap + 'top25/'
         WHERE [week] IS NULL OR [week] <> 'ncaa'

        UPDATE @events
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE 'c.southeastern' IN (away_team_conference, home_team_conference)

        UPDATE e
           SET link_preview = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)

        UPDATE e
           SET link_recap = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)
    END

    -- NCAA HACK
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE @events
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE [week] = 'ncaa'

        UPDATE @events
           SET link_preview = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/preview/'
         WHERE [week] = 'ncaa'

        UPDATE e
           SET link_recap = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE [week] = 'ncaa'
    END


    -- LEADERS
    DECLARE @leaders TABLE
    (
        team_key       VARCHAR(100),
        category       VARCHAR(100),
        category_order INT,
        player_value   VARCHAR(100),
        stat_value     VARCHAR(100),
        stat_order     INT
    )

        INSERT INTO @leaders (team_key, category, category_order, player_value, stat_value, stat_order)
        SELECT team_key, category, category_order, player_value, stat_value, stat_order
          FROM dbo.SMG_Events_Leaders
         WHERE event_key = @event_key AND team_key IN (@away_key, @home_key)
*/



    
END


GO
