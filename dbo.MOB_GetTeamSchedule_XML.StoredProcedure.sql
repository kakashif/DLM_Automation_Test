USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetTeamSchedule_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetTeamSchedule_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/08/2015
  -- Description: get team schedule for mobile
  -- Update: 05/18/2015 - John Lin - return error
  --         05/20/2015 - John Lin - add Women's World Cup
  --         06/23/2015 - John Lin - STATS migration
  --		 07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --         07/29/2015 - John Lin - SDI migration
  --	     08/03/2015 - John Lin - retrieve event_id and logo using functions
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

	DECLARE @events TABLE
	(
	    sub_season_type     VARCHAR(100),
	    event_key           VARCHAR(100),
	    event_status        VARCHAR(100),
	    start_date_time_EST DATETIME,
	    [week]              VARCHAR(100),
	    away_team_key       VARCHAR(100),
	    away_team_score     INT,
	    home_team_key       VARCHAR(100),
	    home_team_score     INT,
	    tv_coverage         VARCHAR(100),
	    -- render
	    home_game           INT,
	    event_score         VARCHAR(100),
	    opponent_key        VARCHAR(100),
   	    opponent_abbr       VARCHAR(100),
	    opponent_short      VARCHAR(100),
	    opponent_long       VARCHAR(100),	    
	    opponent_logo       VARCHAR(100),
	    opponent_rank       INT,
        event_link          VARCHAR(100),
	    -- exra
	    event_id            VARCHAR(100),
	    sub_season_order    INT DEFAULT 1
	)
    INSERT INTO @events (sub_season_type, event_key, event_status, start_date_time_EST, [week], away_team_key, away_team_score,
                         home_team_key, home_team_score, tv_coverage)
    SELECT sub_season_type, event_key, event_status, start_date_time_EST,
           CASE
               WHEN @leagueName IN ('natl', 'wwc') THEN level_id
               ELSE [week]
           END,
           away_team_key, away_team_score,
           home_team_key, home_team_score, tv_coverage
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND event_status <> 'smg-not-played'

    -- extra
    UPDATE @events
       SET home_game = 0, opponent_key = home_team_key
     WHERE away_team_key = @team_key

    UPDATE @events
       SET home_game = 1, opponent_key = away_team_key
     WHERE home_team_key = @team_key

    UPDATE @events
       SET event_score = CASE
                             WHEN home_game = 0 AND away_team_score > home_team_score THEN 'W'
                             WHEN home_game = 0 AND away_team_score < home_team_score THEN 'L'
                             WHEN home_game = 1 AND home_team_score > away_team_score THEN 'W'
                             WHEN home_game = 1 AND home_team_score < away_team_score THEN 'L'
                             ELSE 'T'
                         END + ' ' + CAST(away_team_score AS VARCHAR) + '-' + CAST(home_team_score AS VARCHAR)

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    IF (@leagueName IN ('mls', 'wwc'))
    BEGIN
        UPDATE @events
           SET event_link = 'http://www.usatoday.com/sports/soccer/' + @leagueName + '/event/' + CAST(@season_key AS VARCHAR) + '/' + event_id +
                            CASE
                                WHEN event_status = 'pre-event' THEN '/preview/'
                                ELSE '/boxscore/'
                            END
    END
    ELSE
    BEGIN
        UPDATE @events
           SET event_link = 'http://www.usatoday.com/sports/' + @leagueName + '/event/' + CAST(@season_key AS VARCHAR) + '/' + event_id +
                            CASE
                                WHEN event_status = 'pre-event' THEN '/preview/'
                                ELSE '/boxscore/'
                            END
    END
    
    -- team
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        -- coaches' ranking
        UPDATE e
           SET e.opponent_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.opponent_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = CAST(e.[week] AS INT)

        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            UPDATE e
               SET e.opponent_rank = enbt.seed, e.event_link = REPLACE(e.event_link, 'event', 'bracket')
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = @season_key AND enbt.team_key = e.opponent_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'
        END

        UPDATE e
           SET e.opponent_short = st.team_first,
               e.opponent_long = st.team_first + ' ' + st.team_last,
               e.opponent_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @season_key AND st.team_key = e.opponent_key
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        UPDATE e
           SET e.opponent_short = st.team_first,
               e.opponent_long = st.team_first,
               e.opponent_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = 'wwc' AND st.season_key = @season_key AND st.team_key = e.opponent_key
    END
    ELSE
    BEGIN
        UPDATE e
           SET e.opponent_short = st.team_last,
               e.opponent_long = st.team_first + ' ' + st.team_last,
               e.opponent_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @season_key AND st.team_key = e.opponent_key
    END

    -- logo
    UPDATE @events
       SET opponent_logo = dbo.SMG_fnTeamLogo(@leagueName, opponent_abbr, '22')

    -- order
    IF EXISTS (SELECT 1 FROM @events WHERE sub_season_type = 'post-season')
    BEGIN
        UPDATE @events
           SET sub_season_order = CASE
                                      WHEN sub_season_type = 'post-season' THEN 1
                                      WHEN sub_season_type = 'season-regular' THEN 2
                                      WHEN sub_season_type = 'pre-season' THEN 3
                                      ELSE 0
                                  END
    END
    ELSE
    BEGIN
        DECLARE @today DATE = CAST(GETDATE() AS DATE)
        DECLARE @regular_season DATE

        SELECT TOP 1 @regular_season = CAST(start_date_time_EST AS DATE)
          FROM @events
         WHERE sub_season_type = 'season-regular'
         ORDER BY start_date_time_EST ASC

        IF (@regular_season > @today)
        BEGIN
            UPDATE @events
               SET sub_season_order = CASE
                                          WHEN sub_season_type = 'pre-season' THEN 1
                                          WHEN sub_season_type = 'season-regular' THEN 2
                                          ELSE 0
                                      END
        END
        ELSE
        BEGIN
            UPDATE @events
               SET sub_season_order = CASE
                                          WHEN sub_season_type = 'season-regular' THEN 1
                                          WHEN sub_season_type = 'pre-season' THEN 2
                                          ELSE 0
                                      END
        END
    END

    -- convert to text
    UPDATE @events
       SET sub_season_type = CASE
                                 WHEN sub_season_type = 'pre-season' THEN 'Preseason'
                                 WHEN sub_season_type = 'season-regular' THEN 'Regular Season'
                                 WHEN sub_season_type = 'post-season' THEN 'Post Season'
                             END,
           [week] = CASE
                        WHEN [week] = 'playoffs' THEN 'Playoff'
                        WHEN [week] = 'round-of-16' THEN 'Round of 16'
                        WHEN [week] = 'divisional' THEN 'Divisional'
                        WHEN [week] = 'knockout-round' THEN 'Knockout Round'
                        WHEN [week] = 'semifinals' THEN 'Semifinals'
                        WHEN [week] = 'wild-card' THEN 'Wild Card'
                        WHEN [week] = 'quarterfinals' THEN 'Quarterfinals'
                        WHEN [week] = 'mls-cup' THEN 'MLS Cup'
                        WHEN [week] = 'final' THEN 'Final'
                        WHEN [week] = 'hall-of-fame' THEN 'Hall of Fame'
                        WHEN [week] = 'conference-finals' THEN 'Conference Finals'
                        WHEN [week] = 'conference' THEN 'Conference'
                        WHEN [week] = 'bowls' THEN 'Bowls'
                        ELSE [week]
                    END                  



    SELECT
	(
        SELECT s.sub_season_type AS sub_season,
			   (
                   SELECT e.event_status, e.start_date_time_EST, e.event_link, e.[week], e.home_game, e.event_score,
                          e.opponent_abbr, e.opponent_short, e.opponent_long, e.opponent_logo
                     FROM @events AS e
                    WHERE e.sub_season_type = s.sub_season_type
                    ORDER BY e.start_date_time_EST ASC
                      FOR XML RAW('event'), TYPE
               )				   
          FROM @events AS s
         GROUP BY s.sub_season_type, s.sub_season_order
         ORDER BY s.sub_season_order ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	
END

GO
