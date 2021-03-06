USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScores_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScores_XML]
   @leagueName VARCHAR(100),
   @seasonKey INT = NULL,
   @subSeasonType VARCHAR(100) = NULL,
   @week VARCHAR(100) = NULL,
   @startDate DATETIME = NULL,
   @filter	VARCHAR(100) = NULL,
   @round VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/02/2013
  -- Description: get scores by date for jameson
  -- Update: 06/20/2014 - John Lin - add odds and tv coverage
  --         07/25/2014 - John Lin - lower case for team key
  --         08/19/2014 - ikenticus - added sub_season_type
  --         09/08/2014 - ikenticus - switching to NCAA whitebg logos
  --         09/09/2014 - John Lin - update rank logic
  --         09/12/2014 - John Lin - update display order  
  --         09/23/2014 - ikenticus - adding EPL/Champions
  --         09/25/2014 - John Lin - team TBA
  --         09/26/2014 - John Lin - suppress data base on event status
  --         10/02/2014 - ikenticus - forgot to alter EPL/Champions logos
  --         10/09/2014 - John Lin - whitebg
  --         10/10/2014 - John Lin - set ncaab week
  --         10/16/2014 - ikenticus - suppress record for TBA as well
  --         10/17/2014 - ikenticus - added names for TBA
  --         10/21/2014 - Joh Lin - add play off indicator
  --         10/23/2014 - John Lin - add round
  --         11/11/2014 - John Lin - add header directory
  --         11/25/2014 - John Lin - ncaa check if team last is null
  --         12/04/2014 - John Lin - weekly schedule render today rule
  --         12/05/2014 - ikenticus - fixing TBA logic for EPL/Champions to blank records
  --         12/08/2014 - John Lin - ncaaf daily
  --         12/12/2014 - John Lin - header image for ncaaf playoffs only
  --                               - hard code post season for daily ncaaf
  --         12/17/2014 - ikenticus - restricted TBA logic to EPL/Champions only
  --         01/12/2014 - John Lin - ncaa check if team last is null
  --         03/03/2015 - ikenticus - SJ-1399: NCAA @ Majors
  --         03/09/2015 - ikenticus - SOC-183: adjusting MLS short names to use team_display
  --         03/10/2015 - ikenticus - SOC-184: adding EPL, Champions to the NFL ordering logic
  --		 04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
  --         04/22/2015 - John Lin - use mobile ribbon
  --         04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
  --         04/28/2015 - John Lin - update condition for ncaa at mlb
  --         04/29/2015 - ikenticus: adjusting event_id from SDI vs XT/TSN
  --         05/14/2015 - ikenticus: adding event_id fallback (stats) after passing thru xmlteam/sdi logic
  --         05/15/2015 - ikenticus: adding some name logic for european soccer leagues
  --         05/18/2015 - John Lin - add flag folder for Women's World Cup
  --         06/08/2015 - ikenticus - setting correct date_order when "week" is actually more than 7 days
  --         06/18/2015 - ikenticus - switching NBA Finals flag from week to level_id
  --         06/30/2015 - John Lin - check winner key
  --		 07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --         07/10/2015 - John Lin - STATS team records
  --         07/28/2015 - John Lin - MLS All Stars
  --         08/12/2015 - ikenticus - refactor euro soccer to accept both weekly and daily API calls
  --         08/18/2015 - John Lin - SDI migration
  --         10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        RETURN
    END
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @default_week VARCHAR(100)
    DECLARE @header_image VARCHAR(100)
/* ux 1.0.1
    DECLARE @no_event_message VARCHAR(100)
*/
   	
	DECLARE @events TABLE
	(
        season_key INT,
        sub_season_type VARCHAR(100),
        event_key VARCHAR(100),
        event_status VARCHAR(100),
        game_status VARCHAR(100),
        odds VARCHAR(100),
        tv_coverage VARCHAR(100),
        start_date_time_EST DATETIME,
        start_date_time_UTC DATETIME,
        winner_key VARCHAR(100),
        [week] VARCHAR(100),
        level_id VARCHAR(100),
        ribbon VARCHAR(100),
        -- home
        away_key VARCHAR(100),        
        away_score INT,
        away_winner VARCHAR(100),
        away_abbr VARCHAR(100),
        away_short VARCHAR(100),
        away_long VARCHAR(100),
        away_logo VARCHAR(100),
        away_record VARCHAR(100),
        away_rank VARCHAR(100) DEFAULT NULL,
        -- away
        home_key VARCHAR(100),
        home_score INT,
        home_winner VARCHAR(100),
        home_abbr VARCHAR(100),
        home_short VARCHAR(100),
        home_long VARCHAR(100),
        home_logo VARCHAR(100),
        home_record VARCHAR(100),
        home_rank VARCHAR(100) DEFAULT NULL,
	    -- extra
        level_name VARCHAR(100),
        away_conference VARCHAR(100),
        home_conference VARCHAR(100),
        event_id VARCHAR(100),
        detail_endpoint VARCHAR(100),
        event_date DATE,
        event_date_display VARCHAR(100),
	    date_order           INT,
	    status_order         INT,
	    time_order           INT
	)
	DECLARE @type VARCHAR(100) = 'daily'
    DECLARE @today DATE = CAST(GETDATE() AS DATE)
    DECLARE @default_date DATE = @today
    
    IF (CAST(GETDATE() AS TIME) < '11:00:00')
    BEGIN
        SELECT @default_date = DATEADD(DAY, -1, @default_date)
    END
    

    IF (@round IS NOT NULL)
    BEGIN
        SET @type = 'weekly'

        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
                             start_date_time_EST, winner_key, [week], level_id, away_key, away_score, home_key, home_score)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
               start_date_time_EST, winner_team_key, [week], level_id, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND level_id = @round

        IF (@leagueName = 'ncaab')
        BEGIN
            SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/header/ncaa_tournament.png'
        END
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        IF (@seasonKey IS NULL OR @subSeasonType IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END
               
        SET @type = 'weekly'
        
        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'nfl' AND page = 'scores'

        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
                            start_date_time_EST, winner_key, [week], level_id, away_key, away_score, home_key, home_score)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
               start_date_time_EST, winner_team_key, [week], level_id, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND [week] = @week AND event_status <> 'smg-not-played'
    END
    ELSE IF (@leagueName = 'ncaaf' AND @week IS NOT NULL)
    BEGIN
        IF (@seasonKey IS NULL)
        BEGIN
            RETURN
        END
        
        SET @type = 'weekly'

        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'scores'
        
        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
                             start_date_time_EST, winner_key, [week], level_id, away_key, away_score, home_key, home_score)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage,
               start_date_time_EST, winner_team_key, [week], level_id, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc') AND @week IS NOT NULL)
    BEGIN
        IF (@seasonKey IS NULL)
        BEGIN
            RETURN
        END

        SET @type = 'weekly'
        
        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'scores'

        INSERT INTO @events (season_key, event_key, event_status, game_status, odds, tv_coverage,
                            start_date_time_EST, winner_key, [week], level_id, away_key, away_score, home_key, home_score)
        SELECT season_key, event_key, event_status, game_status, odds, tv_coverage,
               start_date_time_EST, winner_team_key, [week], level_id, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week AND event_status <> 'smg-not-played'
    END
    ELSE
    BEGIN
        IF (@startDate IS NULL)
        BEGIN
            RETURN
        END

        DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 1, @startDate))

        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage, start_date_time_EST,
                             winner_key, [week], level_id, away_key, away_score, home_key, home_score, level_name)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, odds, tv_coverage, start_date_time_EST,
               winner_team_key, [week], level_id, away_team_key, away_team_score, home_team_key, home_team_score, level_name
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @startDate AND @end_date AND event_status <> 'smg-not-played'

        IF (@leagueName = 'mlb' AND EXISTS (SELECT 1 FROM @events WHERE sub_season_type = 'post-season'))
        BEGIN
            SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/header/post_season.png'
        END
        ELSE IF (@leagueName = 'nba' AND EXISTS (SELECT 1 FROM @events WHERE level_id = 'finals'))
        BEGIN
            SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/nba-whitebg/header/finals.png'
        END
        ELSE IF (@leagueName = 'ncaaf')
        BEGIN
            UPDATE @events
               SET sub_season_type = 'post-season'
               
            IF (@filter = 'playoffs')
            BEGIN
                SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/header/playoffs.png'
            END
        END
        ELSE IF (@leagueName = 'nhl' AND EXISTS (SELECT 1 FROM @events WHERE sub_season_type = 'post-season'))
        BEGIN
            SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/nhl-whitebg/header/playoffs.png'
        END
    END

    UPDATE @events
       SET start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), start_date_time_EST)
   
    -- abbreviaton and logo
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        UPDATE e
           SET e.away_abbr = st.team_abbreviation, e.away_conference = st.conference_key,
               e.away_short = st.team_first, e.away_long = CASE
                                                               WHEN st.team_last IS NULL THEN st.team_first
                                                               ELSE st.team_first + ' ' + st.team_last
                                                           END
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.away_key

        UPDATE e
           SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key,
               e.home_short = st.team_first, e.home_long = CASE
                                                               WHEN st.team_last IS NULL THEN st.team_first
                                                               ELSE st.team_first + ' ' + st.team_last
                                                           END
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.home_key
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc'))
    BEGIN
        IF (@leagueName IN ('natl', 'wwc', 'epl', 'champions'))
        BEGIN

            UPDATE e
               SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key,
                   e.home_short = st.team_last, e.home_long = st.team_first
              FROM @events e
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = e.season_key AND st.team_key = e.home_key

            UPDATE e
               SET e.away_abbr = st.team_abbreviation, e.away_conference = st.conference_key,
                   e.away_short = st.team_first, e.away_long = st.team_first
              FROM @events e
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = e.season_key AND st.team_key = e.away_key

            UPDATE e
               SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key,
                   e.home_short = st.team_first, e.home_long = st.team_first
              FROM @events e
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = e.season_key AND st.team_key = e.home_key
        END
        ELSE
        BEGIN
            UPDATE e
               SET e.away_abbr = st.team_abbreviation, e.away_conference = st.conference_key,
                   e.away_short = st.team_first, e.away_long = st.team_first
              FROM @events e
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = e.season_key AND st.team_key = e.away_key

            UPDATE e
               SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key,
                   e.home_short = st.team_last, e.home_long = st.team_first
              FROM @events e
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = e.season_key AND st.team_key = e.home_key
        END
    END
    ELSE
    BEGIN
        UPDATE e
           SET e.away_abbr = st.team_abbreviation, e.away_conference = st.conference_key,
               e.away_short = CASE
                                  WHEN st.league_key = @league_key THEN st.team_display
                                  WHEN st.team_last IS NULL THEN st.team_first
                                  ELSE st.team_last 
                              END,
               e.away_long = CASE
                                 WHEN st.team_last IS NULL THEN st.team_first
                                 ELSE st.team_first + ' ' + st.team_last
                             END
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.away_key

        UPDATE e
           SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key,
               e.home_short = CASE
                                  WHEN st.league_key = @league_key THEN st.team_display
                                  WHEN st.team_last IS NULL THEN st.team_first
                                  ELSE st.team_last 
                              END,
               e.home_long = CASE
                                 WHEN st.team_last IS NULL THEN st.team_first
                                 ELSE st.team_first + ' ' + st.team_last
                             END
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.home_key
    END

	UPDATE @events
	   SET away_logo = dbo.SMG_fnTeamLogo(@leagueName, away_abbr, '110'),
		   home_logo = dbo.SMG_fnTeamLogo(@leagueName, home_abbr, '110')

	IF (@leagueName = 'mls')
	BEGIN
		UPDATE @events
		   SET away_logo = dbo.SMG_fnTeamLogo(@leagueName, 'euro', '110')
		 WHERE level_name = 'exhibition'
	END  


	-- HACK: pre-season NCAA at Majors (apparently, pre-season is not passed for daily)
    IF EXISTS(SELECT 1 FROM @events WHERE away_logo IS NULL) --AND @subSeasonType = 'pre-season'
	BEGIN
		UPDATE @events
		   SET e.away_abbr = t.team_abbreviation, e.away_short = t.team_abbreviation,
		       e.away_long = t.team_first, e.away_key = t.team_key
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Teams t 
		    ON t.team_abbreviation IS NOT NULL AND t.team_abbreviation <> '' AND
		       t.team_abbreviation = away_short OR t.team_key LIKE '%' + RIGHT(away_key, CHARINDEX('.t-', REVERSE(away_key)))
         WHERE e.away_logo IS NULL

        UPDATE @events
           SET away_logo = dbo.SMG_fnTeamLogo('ncaa', away_abbr, '110')
         WHERE away_logo IS NULL
    END


    -- pre event - null score
    UPDATE @events
       SET away_score = NULL, home_score = NULL
     WHERE event_status IN ('pre-event')

    UPDATE @events
       SET away_record = dbo.SMG_fn_Team_Records(@leagueName, season_key, away_key, event_key),
           home_record = dbo.SMG_fn_Team_Records(@leagueName, season_key, home_key, event_key)

    -- team TBA
	IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc'))
	BEGIN
		UPDATE @events
		   SET away_logo = '', away_record = '', away_short = 'TBA', away_long = 'To Be Announced'
		 WHERE away_abbr IS NULL
		 
		UPDATE @events
		   SET home_logo = '', home_record = '', home_short = 'TBA', home_long = 'To Be Announced'
		 WHERE home_abbr IS NULL
	END
	ELSE
	BEGIN
		UPDATE @events
		   SET away_logo = '', away_record = ''
		 WHERE away_abbr = 'TBA'

		UPDATE @events
		   SET home_logo = '', home_record = ''
		 WHERE home_abbr = 'TBA'
	END


    UPDATE e
       SET e.ribbon = tag.mobile
      FROM @events e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key

    UPDATE @events
       SET away_winner = '1', home_winner = '0'
     WHERE event_status = 'post-event' AND away_score > home_score

    UPDATE @events
       SET home_winner = '1', away_winner = '0'
     WHERE event_status = 'post-event' AND home_score > away_score

    UPDATE @events
       SET away_winner = '1', home_winner = '0'
     WHERE event_status = 'post-event' AND away_key = winner_key

    UPDATE @events
       SET home_winner = '1', away_winner = '0'
     WHERE event_status = 'post-event' AND home_key = winner_key
    
    -- endpoint: xmlteam
    UPDATE @events
       SET event_id = REPLACE(event_key, @league_key + '-' + CAST(season_key AS VARCHAR) + '-e.', '')
	 WHERE event_key LIKE '%-e.%'

    -- endpoint: sdi
    UPDATE @events
       SET event_id = REVERSE(LEFT(REVERSE(event_key), CHARINDEX(':', REVERSE(event_key)) - 1))
	 WHERE event_key LIKE '%:%'

    -- endpoint: stats (fallback)
    UPDATE @events
       SET event_id = event_key
	 WHERE event_id IS NULL

    UPDATE @events
       SET detail_endpoint = '/Event.svc/matchup/' + @leagueName + '/' + CAST(season_key AS VARCHAR) + '/' + event_id


    -- FILTER
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            SELECT TOP 1 @seasonKey = season_key, @week = [week]
              FROM @events
             ORDER BY start_date_time_EST DESC
        END

        DECLARE @poll_week INT
        
        IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
                                               FROM SportsEditDB.dbo.SMG_Polls
                                              WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND [week] = CAST(@week AS INT)))
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
        
        UPDATE e
           SET e.away_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_abbr AND sp.[week] = @poll_week
               
        UPDATE e
           SET e.home_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_abbr AND sp.[week] = @poll_week
        
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            UPDATE e
               SET e.away_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.away_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

            UPDATE e
               SET e.home_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.home_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'
        END

        -- assume no events
        UPDATE @events
           SET status_order = 0

        IF (@round IS NOT NULL)
        BEGIN
            UPDATE @events
               SET status_order = 1            
        END
        ELSE IF (@filter = 'top25')
        BEGIN           
            UPDATE @events
               SET status_order = 1
             WHERE (CAST (ISNULL(NULLIF(home_rank, ''), '0') AS INT) + CONVERT(INT, ISNULL(NULLIF(away_rank, ''), '0'))) > 0

            IF NOT EXISTS (SELECT 1 FROM @events WHERE status_order = 1)
            BEGIN
/* ux 1.0.0 */
                UPDATE @events
                   SET status_order = 1
/* ux 1.0.0 */
/* ux 1.0.1
                SET @no_event_message = 'There are no events for Top 25 for the selected date. Please select a conference.'

                IF (@type = 'weekly')
                BEGIN
                    SET @no_event_message = 'There are no events for Top 25 for the selected week. Please select a conference.'
                END
*/                
            END
        END        
        ELSE IF (@filter = 'tourney')
        BEGIN
            UPDATE @events
               SET status_order = 1
             WHERE [week] IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
        END
        ELSE IF (@filter IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
        BEGIN
            UPDATE @events
               SET status_order = 1
             WHERE [week] = @filter
        END
        ELSE IF (@filter IN ('bowls', 'playoffs'))
        BEGIN
            UPDATE @events
               SET status_order = 1
             WHERE level_id = @filter
        END
        ELSE
        BEGIN
            UPDATE e
               SET e.status_order = 1
              FROM @events e
             INNER JOIN dbo.SMG_Leagues l
                ON l.league_key = @league_key AND l.season_key = @seasonKey AND SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display) = @filter AND
                   l.conference_key IN (e.away_conference, e.home_conference)
        END
        
        DELETE @events
         WHERE status_order = 0
    END


    -- ORDER
    IF (@leagueName IN ('nfl', 'ncaaf', 'champions', 'epl', 'natl', 'wwc'))
    BEGIN
		DECLARE @max_order INT

        UPDATE @events
           SET date_order = DATEDIFF(DAY, @default_date, CAST(start_date_time_EST AS DATE))

		SELECT @max_order = MAX(date_order)
		  FROM @events

        IF (@default_week = @week)
        BEGIN        
            UPDATE @events
               SET date_order = (date_order * -@max_order + 1)
             WHERE date_order < 0
        END
    END

    UPDATE @events
       SET status_order = (CASE
	                          WHEN event_status = 'mid-event' THEN 1
                              WHEN event_status = 'intermission' THEN 2
               	              WHEN event_status = 'weather-delay' THEN 3
	                          WHEN event_status = 'post-event' THEN 4
	                          WHEN event_status = 'pre-event' THEN 5
	                          WHEN event_status = 'suspended' THEN 6
	                          WHEN event_status = 'postponed' THEN 7
	                          WHEN event_status = 'canceled' THEN 8
	                      END)

    UPDATE @events
       SET time_order = DATEPART(HOUR, start_date_time_EST) * 100 + DATEPART(MINUTE, start_date_time_EST)
       
    IF (@leagueName IN ('nfl', 'ncaaf') AND @default_week = @week)
    BEGIN
        UPDATE @events
           SET time_order = (time_order * -1)
         WHERE event_status = 'post-event'
    END

    -- suppress
    UPDATE @events
       SET odds = ''
     WHERE event_status NOT IN ('pre-event', 'postponed', 'canceled')

    UPDATE @events
       SET tv_coverage = ''
     WHERE event_status NOT IN ('pre-event', 'mid-event', 'intermission', 'weather-delay')

    UPDATE @events
       SET tv_coverage = SUBSTRING(tv_coverage, 1, CHARINDEX(',', tv_coverage) - 1)
     WHERE LEN(tv_coverage) > 12 AND CHARINDEX(',', tv_coverage) > 0


    IF (@type = 'daily')
    BEGIN
        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT @type AS [type], @header_image AS header_image, /* ux 1.0.1 @no_event_message AS no_event_message, */
	           (
		           SELECT 'true' AS 'json:Array',
		                  e.sub_season_type, e.event_key, e.ribbon, e.game_status, e.event_status, e.odds, e.tv_coverage, e.detail_endpoint, e.start_date_time_UTC,
			             (
				             SELECT a_e.away_abbr AS abbr,
    						        a_e.away_logo AS logo,
								    a_e.away_long AS long,
								    a_e.away_short AS short,
								    a_e.away_record AS record,
	    							a_e.away_rank AS [rank],
		    						a_e.away_score AS score,
								    a_e.away_winner AS winner
						       FROM @events a_e
						      WHERE a_e.event_key = e.event_key
						        FOR XML RAW('away'), TYPE                   
						 ),
						 ( 
				             SELECT h_e.home_abbr AS abbr,
    						        h_e.home_logo AS logo,
								    h_e.home_long AS long,
								    h_e.home_short AS short,
								    h_e.home_record AS record,
	    							h_e.home_rank AS [rank],
		    						h_e.home_score AS score,
								    h_e.home_winner AS winner
						       FROM @events h_e
						      WHERE h_e.event_key = e.event_key
						        FOR XML RAW('home'), TYPE
						 )
					  FROM @events e
					 ORDER BY e.status_order ASC, e.start_date_time_EST ASC
					   FOR XML RAW('events'), TYPE
	           )
	       FOR XML PATH(''), ROOT('root')
	END
	ELSE
	BEGIN
        UPDATE @events
           SET event_date = CAST(start_date_time_EST AS DATE)
        
        UPDATE @events
           SET event_date_display = DATENAME(WEEKDAY, event_date) + ', ' + DATENAME(MONTH, event_date) + ' ' + CAST(DAY(event_date) AS VARCHAR)
          
		UPDATE @events
		   SET event_date_display = 'Today'
		 WHERE event_date = @today

        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT @type AS [type], @header_image AS header_image, /* ux 1.0.1 @no_event_message AS no_event_message, */
	           (
		           SELECT 'true' AS 'json:Array',
		                  g.event_date,  g.event_date_display,
	                      (
		                      SELECT 'true' AS 'json:Array',
		                             e.sub_season_type, e.event_key, e.ribbon, e.game_status, e.event_status, e.odds, e.tv_coverage, e.detail_endpoint, e.start_date_time_UTC,
			                         (
				                         SELECT a_e.away_abbr AS abbr,
    						                    a_e.away_logo AS logo,
    						                    a_e.away_long AS long,
    						                    a_e.away_short AS short,
    						                    a_e.away_record AS record,
    						                    a_e.away_rank AS [rank],
    						                    a_e.away_score AS score,
    						                    a_e.away_winner AS winner
						                   FROM @events a_e
						                  WHERE a_e.event_key = e.event_key
						                    FOR XML RAW('away'), TYPE                   
						             ),
						             ( 
				                         SELECT h_e.home_abbr AS abbr,
    						                    h_e.home_logo AS logo,
    						                    h_e.home_long AS long,
    						                    h_e.home_short AS short,
    						                    h_e.home_record AS record,
    						                    h_e.home_rank AS [rank],
    						                    h_e.home_score AS score,
    						                    h_e.home_winner AS winner
    						               FROM @events h_e
    						              WHERE h_e.event_key = e.event_key
    						                FOR XML RAW('home'), TYPE
						  )
					 FROM @events e
					WHERE e.event_date = g.event_date
					ORDER BY e.status_order ASC, e.time_order ASC
					  FOR XML RAW('events'), TYPE
		         )
		    FROM @events g
	       GROUP BY g.date_order, g.event_date, g.event_date_display
	       ORDER BY g.date_order ASC
	         FOR XML RAW('event_dates'), TYPE
	          )
	      FOR XML PATH(''), ROOT('root')
	END
END


GO
