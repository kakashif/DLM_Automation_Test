USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PRT_Publish_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PRT_Publish_XML]
AS
-- =============================================
-- Author: John Lin
-- Create date: 07/21/2015
-- Description:	get box list
-- Update: 07/24/2015 - John Lin - add post to print_status
--         08/14/2015 - John Lin - update to use source
--         08/21/2015 - John Lin - add NFL
--         09/14/2015 - John Lin - check team and player are current
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     

    DECLARE @now DATETIME = GETDATE()
    
    DECLARE @event_keys TABLE
    (
        league_key VARCHAR(100),
        event_key VARCHAR(100),
        away_team_key VARCHAR(100),
        home_team_key VARCHAR(100),
        print_status VARCHAR(100),
        date_time VARCHAR(100),
        -- extra
        [source] VARCHAR(100),
        league_name VARCHAR(100),
        season_key INT,
        sub_season_type VARCHAR(100),
        event_id INT,
        away_team_id VARCHAR(100),
        away_team_abbr VARCHAR(100),
        home_team_id VARCHAR(100),
        home_team_abbr VARCHAR(100),
        -- verify
        schedule_date_time DATETIME,
        -- verify
        verify_date_time_max VARCHAR(100),
        verify_date_time DATETIME,
        [week] INT DEFAULT 0,
        games_played INT
    )
    INSERT INTO @event_keys(league_key, season_key, sub_season_type, event_key, away_team_key, home_team_key, date_time, print_status, schedule_date_time)
    SELECT league_key, season_key, sub_season_type, event_key, away_team_key, home_team_key, date_time, print_status, start_date_time_EST
      FROM dbo.SMG_Schedules
     WHERE league_key IN ('/sport/football/league:1', '/sport/baseball/league:1219') AND
           event_status = 'post-event' AND start_date_time_EST BETWEEN DATEADD(DAY, -1, @now) AND @now

    UPDATE @event_keys
       SET league_name = 'nfl'
     WHERE league_key = '/sport/football/league:1'

    UPDATE @event_keys
       SET league_name = 'mlb'
     WHERE league_key = '/sport/baseball/league:1219'

    -- mlb
    DELETE @event_keys
     WHERE league_name = 'mlb' AND print_status = 'box-sent'

    -- credit
    UPDATE e
       SET e.verify_date_time_max = (SELECT MAX(b.date_time)
                                       FROM SportsEditDB.dbo.SMG_Events_baseball b
                                      WHERE b.event_key = e.event_key AND b.[column] = 'event-credit')
      FROM @event_keys e
     WHERE e.league_name = 'mlb'

    UPDATE @event_keys
       SET verify_date_time = CAST(REPLACE(LEFT(verify_date_time_max, 19), 'T', ' ') AS DATETIME)
     WHERE league_name = 'mlb'

    -- remove if no date_time
    DELETE @event_keys
     WHERE league_name = 'mlb' AND verify_date_time IS NULL

    -- remove if not current
    DELETE @event_keys
     WHERE league_name = 'mlb' AND DATEADD(HOUR, 1, schedule_date_time) > verify_date_time

    UPDATE @event_keys
       SET print_status = 'box'
     WHERE league_name = 'mlb'


    -- nfl
    DELETE @event_keys
     WHERE league_name = 'nfl' AND print_status = 'stats-sent'

    -- time_of_possession_secs
    UPDATE e
       SET e.verify_date_time_max = (SELECT s.date_time
                                       FROM dbo.SMG_Scores s
                                      WHERE s.event_key = e.event_key AND s.[column] = 'game-duration-mins')
      FROM @event_keys e
     WHERE e.league_name = 'nfl' AND e.print_status <> 'box-sent'

    UPDATE @event_keys
       SET verify_date_time = CAST(REPLACE(LEFT(verify_date_time_max, 19), 'T', ' ') AS DATETIME)
     WHERE league_name = 'nfl' AND print_status <> 'box-sent'

    -- remove if no date_time
    DELETE @event_keys
     WHERE league_name = 'nfl' AND print_status <> 'box-sent' AND verify_date_time IS NULL

    -- remove if not current
    DELETE @event_keys
     WHERE league_name = 'nfl' AND print_status <> 'box-sent' AND DATEADD(HOUR, 1, schedule_date_time) > verify_date_time

    UPDATE @event_keys
       SET print_status = 'box'
     WHERE league_name = 'nfl' AND print_status <> 'box-sent'


    -- games_played
    -- team
    UPDATE e
       SET e.games_played = (SELECT CAST(value AS INT)
                               FROM SportsEditDB.dbo.SMG_Statistics s
                              WHERE s.league_key = e.league_key AND s.season_key = e.season_key AND s.sub_season_type = e.sub_season_type AND
                                    s.team_key = e.away_team_key AND s.player_key = 'team' AND s.category = 'feed' AND s.[column] = 'games_played')
      FROM @event_keys e
     WHERE e.league_name = 'nfl' AND print_status = 'box-sent'

    UPDATE e
       SET e.[week] = (SELECT COUNT(*)
                               FROM SportsDB.dbo.SMG_Schedules s
                              WHERE s.league_key = e.league_key AND s.season_key = e.season_key AND s.sub_season_type = e.sub_season_type AND
                                    e.away_team_key IN (s.away_team_key, s.home_team_key) AND s.start_date_time_EST <= e.schedule_date_time)
      FROM @event_keys e
     WHERE e.league_name = 'nfl' AND e.print_status = 'box-sent'

    UPDATE @event_keys
       SET print_status = 'stats'
     WHERE league_name = 'nfl' AND print_status = 'box-sent' AND games_played = [week]




    UPDATE e
       SET e.away_team_abbr = t.team_abbreviation
      FROM @event_keys e
     INNER JOIN dbo.SMG_Teams t
        ON t.league_key = e.league_key AND t.season_key = e.season_key AND t.team_key = e.away_team_key

    UPDATE e
       SET e.home_team_abbr = t.team_abbreviation
      FROM @event_keys e
     INNER JOIN dbo.SMG_Teams t
        ON t.league_key = e.league_key AND t.season_key = e.season_key AND t.team_key = e.home_team_key
    
    UPDATE @event_keys
       SET event_id = dbo.SMG_fnEventId(event_key),
           away_team_id = dbo.SMG_fnEventId(away_team_key),
           home_team_id = dbo.SMG_fnEventId(home_team_key)

    SELECT
    (
        SELECT league_key, event_key, away_team_key, home_team_key, print_status, date_time, league_name, event_id, away_team_id, away_team_abbr, home_team_id, home_team_abbr
		  FROM @event_keys
	       FOR XML RAW('box'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END


GO
