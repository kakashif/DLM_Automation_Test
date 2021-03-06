USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetTeamSchedules_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetTeamSchedules_XML]
	@leagueName VARCHAR(100),
	@teamSlug   VARCHAR(100),
	@seasonKey  INT
AS
--=============================================
-- Author:	ikenticus
-- Create date:	05/20/2015
-- Description:	get team schedules
-- Update:		06/01/2015 - John Lin - refactored/optimized to use opponent instead of away/home
--				06/02/2015 - ikenticus - adding World Cup ribbons
--				06/18/2015 - ikenticus - grabbing level name instead of week for NBA
--		   		07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--              07/29/2015 - John Lin - SDI migration
--              08/03/2015 - John Lin - retrieve event_id and logo using functions
--				09/01/2015 - ikenticus - providing missing game_status for TBA
--				09/04/2015 - ikenticus - forgot to prepend /soccer/ for the soccer league links
--              10/20/2015 - John Lin - NCAA basketball week = NULL for regular season
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @sport VARCHAR(100) = 'mens-basketball'
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_conference VARCHAR(100)

	SELECT @team_key = team_key, @team_conference = conference_key
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

	DECLARE @events TABLE
	(
	    sub_season_type     VARCHAR(100),
	    event_key           VARCHAR(100),
	    start_date_time_EST DATETIME,
	    [week]              VARCHAR(100),
	    level_name          VARCHAR(100),
	    game_status        VARCHAR(100),
	    event_status        VARCHAR(100),
	    away_team_key       VARCHAR(100),
	    away_team_score     INT,
	    home_team_key       VARCHAR(100),
	    home_team_score     INT,
	    tv_coverage         VARCHAR(100),
	    -- render
	    symbol              VARCHAR(100),
	    event_score         VARCHAR(100),
	    opponent_key        VARCHAR(100),
	    opponent_name       VARCHAR(100),
	    opponent_logo       VARCHAR(100),
	    opponent_rank       INT,
	    opponent_conference VARCHAR(100),
        link_event          VARCHAR(100),
        link_preview        VARCHAR(100),
        link_boxscore       VARCHAR(200),
        link_recap          VARCHAR(100),
	    -- exra
	    event_id            VARCHAR(100),
   	    opponent_abbr       VARCHAR(100),
	    ribbon              VARCHAR(100) DEFAULT 'REGULAR SEASON',
	    ribbon_order        INT DEFAULT 1
	)
    INSERT INTO @events (sub_season_type, event_key, start_date_time_EST, [week], game_status, event_status, level_name,
                         away_team_key, away_team_score, home_team_key, home_team_score, tv_coverage)
    SELECT sub_season_type, event_key, start_date_time_EST,
           CASE
               WHEN @leagueName IN ('natl', 'wwc') THEN level_id
               ELSE [week]
           END,

           game_status, event_status, level_name,
           away_team_key, away_team_score, home_team_key, home_team_score, tv_coverage
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND @team_key IN (away_team_key, home_team_key) AND event_status <> 'smg-not-played'

	-- opponents
    UPDATE @events
       SET symbol = '@', opponent_key = home_team_key
     WHERE away_team_key = @team_key

    UPDATE @events
       SET symbol = 'vs.', opponent_key = away_team_key
     WHERE home_team_key = @team_key


    -- team
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        -- coaches' ranking
        UPDATE e
           SET e.opponent_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.opponent_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = CAST(e.[week] AS INT)

        -- post season
        IF (@leagueName = 'ncaaf')
        BEGIN
           SET @sport = 'football'
           
           UPDATE e
              SET e.ribbon = ups.schedule, e.ribbon_order = 0
             FROM @events e
            INNER JOIN dbo.USAT_Post_Seasons ups
               ON ups.event_key = e.event_key
        END
        ELSE
        BEGIN
            UPDATE e
               SET e.opponent_rank = enbt.seed, e.link_event = REPLACE(e.link_event, 'event', 'bracket')
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = @seasonKey AND enbt.team_key = e.opponent_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

            UPDATE e
               SET e.ribbon = ups.dropdown + ' Tournament', e.ribbon_order = 0
              FROM @events e
             INNER JOIN dbo.USAT_Post_Seasons ups
                ON ups.event_key = e.event_key
        END
    END
    ELSE IF (@leagueName IN ('natl', 'wwc'))
    BEGIN
		IF (@leagueName = 'wwc')
		BEGIN
			UPDATE @events
			   SET ribbon = 'Women''s World Cup'
		END
		ELSE
		BEGIN
			UPDATE @events
			   SET ribbon = 'World Cup'
		END
    END
    ELSE
    BEGIN
        DECLARE @end_date DATE
        
        -- pre season
        UPDATE @events
           SET ribbon = 'PRESEASON'
         WHERE sub_season_type = 'pre-season'

        SELECT TOP 1 @end_date = CAST(start_date_time_EST AS DATE)
          FROM @events
         WHERE ribbon = 'PRESEASON'
         ORDER BY start_date_time_EST DESC

        IF (CAST(GETDATE() AS DATE) > @end_date)
        BEGIN
            UPDATE @events
               SET ribbon_order = 2
             WHERE ribbon = 'PRESEASON'

            UPDATE @events
               SET ribbon = 'POSTSEASON', ribbon_order = 0
             WHERE sub_season_type = 'post-season'
        END
        ELSE
        BEGIN
            UPDATE @events
               SET ribbon_order = 0
             WHERE ribbon = 'PRESEASON'
        END

        IF (@leagueName = 'nfl')
        BEGIN
           UPDATE e
              SET e.[week] = ups.dropdown
             FROM @events e
            INNER JOIN dbo.USAT_Post_Seasons ups
               ON ups.event_key = e.event_key

            -- PADDING
            DECLARE @missings TABLE
            (
                [week]          INT,
                missing         INT,
                start_date_time DATETIME
            )
            INSERT INTO @missings ([week], missing)
            VALUES (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1), (17, 1)
            
            UPDATE m
               SET m.missing = 0
              FROM @missings m
             INNER JOIN @events e
                ON e.[week] = m.[week] AND e.ribbon = 'REGULAR SEASON'

            UPDATE m
               SET m.start_date_time = DATEADD(WEEK, 1, e.start_date_time_EST)
              FROM @missings m
             INNER JOIN @events e
                ON e.[week] = (m.[week] - 1) AND e.ribbon = 'REGULAR SEASON'
                
            INSERT INTO @events (start_date_time_EST, [week], ribbon, ribbon_order)
            SELECT start_date_time, [week], 'REGULAR SEASON', 1
              FROM @missings
             WHERE missing = 1
        END
        ELSE IF (@leagueName = 'champions')
	    BEGIN
            -- Datafactory did not provide events prior to Group Stage
            -- Currently suppressing STATS events not regular season until we can process
	    	DELETE @events
	    	 WHERE sub_season_type <> 'season-regular'
	    END
		ELSE IF (@leagueName = 'nba')
        BEGIN
			UPDATE @events
			   SET [week] = level_name
		END
    END

    UPDATE e
       SET e.opponent_name = st.team_first, e.opponent_abbr = st.team_abbreviation, e.opponent_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = e.opponent_key

    -- logo
	UPDATE @events
	   SET opponent_logo = dbo.SMG_fnTeamLogo(@leagueName, opponent_abbr, '30')

    -- extra
    UPDATE @events
       SET event_score = CASE
                             WHEN symbol = '@'   AND away_team_score > home_team_score THEN 'WON('
                             WHEN symbol = '@'   AND away_team_score < home_team_score THEN 'LOST('
                             WHEN symbol = 'vs.' AND home_team_score > away_team_score THEN 'WON('
                             WHEN symbol = 'vs.' AND home_team_score < away_team_score THEN 'LOST('
                             ELSE 'TIE('
                         END + CAST(away_team_score AS VARCHAR) + '-' + CAST(home_team_score AS VARCHAR) + ')'

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    -- LINKS
	DECLARE @coverage TABLE (
		event_key VARCHAR(100),
		column_type VARCHAR(100)
	)
	
	INSERT INTO @coverage (event_key, column_type)
	SELECT ss.event_key, ss.column_type
	  FROM dbo.SMG_Scores ss
	 INNER JOIN @events e
	    ON e.event_key = ss.event_key

    IF (@leagueName IN ('champions', 'epl', 'mls', 'natl', 'wwc'))
    BEGIN
        UPDATE e
           SET e.link_preview = '/sports/soccer/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE @events
           SET link_boxscore = '/sports/soccer/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/boxscore/'


        UPDATE e
           SET e.link_recap = '/sports/soccer/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    ELSE
    BEGIN
        UPDATE e
           SET e.link_preview = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE @events
           SET link_boxscore = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/boxscore/'


        UPDATE e
           SET e.link_recap = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/recap/'
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
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE 'c.southeastern' IN (@team_conference, opponent_conference)

        UPDATE e
           SET e.link_preview = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE 'c.southeastern' IN (@team_conference, opponent_conference)

        UPDATE e
           SET e.link_recap = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE 'c.southeastern' IN (@team_conference, opponent_conference)
    END

    -- NCAA HACK
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE @events
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE [week] = 'ncaa'

        UPDATE @events
           SET link_preview = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/preview/'
         WHERE [week] = 'ncaa'

        UPDATE e
           SET e.link_recap = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE [week] = 'ncaa'
    END

    IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        UPDATE @events
           SET [week] = NULL
         WHERE sub_season_type = 'season-regular'
    END
    
        

    SELECT
	(
        SELECT g.ribbon,
			   (
                   SELECT e.start_date_time_EST, e.[week], e.symbol, e.event_score, e.tv_coverage, e.game_status,
                          e.opponent_name, e.opponent_logo, e.event_status, e.link_event, e.link_preview, e.link_boxscore, e.link_recap 
                     FROM @events AS e
                    WHERE e.ribbon_order = g.ribbon_order
                    ORDER BY e.start_date_time_EST ASC
                      FOR XML RAW('event'), TYPE
               )				   
          FROM @events AS g
         GROUP BY g.ribbon, g.ribbon_order
         ORDER BY g.ribbon_order ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
 
 END


GO
