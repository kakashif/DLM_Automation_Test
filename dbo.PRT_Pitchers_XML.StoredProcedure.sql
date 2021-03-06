USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PRT_Pitchers_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PRT_Pitchers_XML]
AS
-- =============================================
-- Author: John Lin
-- Create date: 07/13/2015
-- Description:	get probable pitchers for print for baseball
-- Update: 07/22/2015 - John Lin - add meridian
--         08/26/2015 - John Lin - minor SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')       

    DECLARE @events TABLE
    (
        season_key INT,
        event_key VARCHAR(100),
        odds VARCHAR(100),
        start_date_time_EST DATETIME,
        away_team_key VARCHAR(100),
        home_team_key VARCHAR(100)
    )
    INSERT INTO @events (season_key, event_key, odds, start_date_time_EST, away_team_key, home_team_key)
    SELECT s.season_key, s.event_key, s.odds, s.start_date_time_EST, s.away_team_key, s.home_team_key
      FROM dbo.SMG_Schedules s
     INNER JOIN dbo.SMG_Transient t
        ON t.event_key = s.event_key
     WHERE s.league_key = @league_key AND s.start_date_time_EST > GETDATE() AND s.event_status = 'pre-event'
     
    DECLARE @pitchers TABLE
    (
        season_key INT,
        event_key VARCHAR(100),
        team_key VARCHAR(100),
        start_date_time_EST DATETIME,
        conference_key VARCHAR(100),
        player_key VARCHAR(100),
        -- render
        league VARCHAR(100),
        team_first VARCHAR(100),
        team_last VARCHAR(100),
        team_abbr VARCHAR(100),
        alignment VARCHAR(100),
        pitcher_first VARCHAR(100),
        pitcher_last VARCHAR(100),
        throwing_hand VARCHAR(100),
        odds VARCHAR(100),
        [date] DATE,
        [time] VARCHAR(100),
        -- statistics
        [events-started] INT,
        wins INT,
        losses INT,
        [winning-percentage] VARCHAR(100),
        whip VARCHAR(100),
        era VARCHAR(100),
        [innings-pitched] VARCHAR(100),
        [opponent-batting-average] VARCHAR(100),
        -- extra
        [outs-pitched] INT,
        earned_run_average VARCHAR(100),
        pitcher_strikeouts INT
    )
    INSERT INTO @pitchers (event_key, alignment)
    SELECT event_key, 'away'
      FROM @events
     GROUP BY event_key
    
    INSERT INTO @pitchers (event_key, alignment)
    SELECT event_key, 'home'
      FROM @events
     GROUP BY event_key

    UPDATE p
       SET p.season_key = e.season_key, p.odds = e.odds, p.start_date_time_EST = e.start_date_time_EST, p.team_key = e.away_team_key
      FROM @pitchers p
     INNER JOIN @events e
        ON e.event_key = p.event_key
     WHERE p.alignment = 'away'
        
    UPDATE p
       SET p.season_key = e.season_key, p.odds = e.odds, p.start_date_time_EST = e.start_date_time_EST, p.team_key = e.home_team_key
      FROM @pitchers p
     INNER JOIN @events e
        ON e.event_key = p.event_key
     WHERE p.alignment = 'home'
    
    UPDATE p
       SET p.player_key = t.player_key
      FROM @pitchers p
     INNER JOIN dbo.SMG_Transient t
        ON t.event_key = p.event_key AND t.team_key = p.team_key
     
    UPDATE @pitchers
       SET [date] = CAST(start_date_time_EST AS DATE),
           [time] = CASE
                        WHEN DATEPART(HOUR, start_date_time_EST) > 12 THEN CAST(DATEPART(HOUR, start_date_time_EST) - 12 AS VARCHAR)
                        ELSE CAST(DATEPART(HOUR, start_date_time_EST) AS VARCHAR)
                    END + ':' +
                    CASE
                        WHEN DATEPART(MINUTE, start_date_time_EST) < 10 THEN '0'
                        ELSE ''
                    END +
                    CAST(DATEPART(MINUTE, start_date_time_EST) AS VARCHAR) + ' ' +
                    CASE
                        WHEN DATEPART(HOUR, start_date_time_EST) < 12 THEN 'AM'
                        ELSE 'PM'
                    END

    UPDATE @pitchers
       SET odds = SUBSTRING(odds, 1, CHARINDEX(' / ', odds))
     WHERE CHARINDEX(' / ', odds) <> 0
      
    -- team info
    UPDATE p
       SET p.conference_key = st.conference_key, p.team_first = st.team_first, p.team_last = st.team_last, p.team_abbr = st.team_abbreviation
      FROM @pitchers p
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = p.season_key AND st.team_key = p.team_key

    -- league
    UPDATE a
       SET a.league = CASE
                          WHEN a.conference_key <> h.conference_key THEN 'INTER'
                          ELSE CASE
                                   WHEN '/sport/baseball/conference:137' IN (a.conference_key, h.conference_key) THEN 'AMERICAN'
                                   ELSE 'NATIONAL'
                               END
                      END
      FROM @pitchers a
     INNER JOIN @pitchers h
        ON a.event_key = h.event_key AND a.alignment <> h.alignment

    -- name
    UPDATE p
       SET p.pitcher_first = sp.first_name, p.pitcher_last = sp.last_name, p.throwing_hand = sp.throwing_hand
      FROM @pitchers p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key

   -- stats
   DECLARE @stats TABLE
   (
       team_key VARCHAR(100),
       player_key VARCHAR(100),
       [column] VARCHAR(100),
       value VARCHAR(100)
   )
   INSERT INTO @stats (team_key, player_key, [column], value)
   select s.team_key, s.player_key, s.[column], s.value
     FROM SportsEditDB.dbo.SMG_Statistics s
    INNER JOIN @pitchers p
       ON p.season_key = s.season_key AND p.team_key = s.team_key AND p.player_key = s.player_key
    WHERE s.league_key = @league_key AND s.sub_season_type = 'season-regular' AND s.category = 'feed' AND
          s.[column] IN ('pitcher_games_started', 'wins', 'losses', 'whip', 'era', 'earned_run_average', 'innings-pitched', 'outs-pitched', 'opponent-batting-average', 'pitching-strikeouts')
    
    UPDATE p
       SET p.[events-started] = ISNULL(t.pitcher_games_started, 0), p.wins = ISNULL(t.wins, 0), p.losses = ISNULL(t.losses, 0),
           p.whip = CAST(CAST(t.whip AS DECIMAL(5, 2)) AS VARCHAR),
           p.era = CAST(CAST(t.era AS DECIMAL(5, 2)) AS VARCHAR),
           p.earned_run_average = t.earned_run_average, p.[innings-pitched] = t.[innings-pitched],
           p.[outs-pitched] = ISNULL(t.[outs-pitched], 0), p.[opponent-batting-average] = t.[opponent-batting-average],
           p.pitcher_strikeouts = ISNULL(t.[pitching-strikeouts], 0)
      FROM @pitchers p
     INNER JOIN (SELECT player_key, team_key, [column], value FROM @stats) AS s
                  PIVOT (MAX(s.value) FOR s.[column] IN (pitcher_games_started, wins, losses, whip, era, earned_run_average, [innings-pitched], [outs-pitched], [opponent-batting-average],
                                                         [pitching-strikeouts])) AS t
        ON t.team_key = p.team_key AND t.player_key = p.player_key

/*
    UPDATE @pitchers
       SET [innings-pitched] = CAST(([outs-pitched] / 3) AS VARCHAR)
     WHERE [outs-pitched] > 0

    UPDATE @pitchers
       SET [innings-pitched] = [innings-pitched] + '.' + CAST(([outs-pitched] % 3) AS VARCHAR)
     WHERE ([outs-pitched] % 3) <> 0
*/
       
    UPDATE @pitchers
       SET [winning-percentage] = REPLACE(CAST(CAST((CAST(wins AS FLOAT) / CAST(wins + losses AS FLOAT)) AS DECIMAL(4, 3)) AS VARCHAR), '0.', '.')
     WHERE wins + losses > 0

    UPDATE @pitchers
       SET [winning-percentage] = 'NA'
     WHERE wins + losses = 0

/*
    UPDATE @pitchers
       SET [winning-percentage] = '1.00'
     WHERE losses = 0

    UPDATE @pitchers
       SET [winning-percentage] = RIGHT([winning-percentage], LEN([winning-percentage]) -1)
     WHERE LEFT([winning-percentage], 1) = '0'
*/


    SELECT
    (
        SELECT d.[date] AS '@date',
        (
            SELECT l.league AS '@league',
            (
                SELECT dbo.SMG_fnEventId(e.event_key) AS '@event-key', e.[time] AS '@time', e.odds AS '@line',
                (
                    SELECT t.alignment AS '@alignment', t.team_first AS '@first', t.team_last AS '@last', t.team_abbr AS '@abbreviation',
                    (
                        SELECT t.pitcher_first AS '@first', t.pitcher_last AS '@last', t.throwing_hand AS '@pitching',
                               t.[events-started] AS '@events-started', t.wins AS '@wins', t.losses AS '@losses', t.[winning-percentage] AS '@winning-percentage',
                               t.whip AS '@whip', t.era AS '@era', t.[innings-pitched] AS '@innings-pitched', t.[opponent-batting-average] AS '@opponent-batting-average',
                               t.pitcher_strikeouts AS '@pitcher-strikeouts'                        
                          FROM @pitchers p
                         WHERE p.event_key = e.event_key AND p.alignment = t.alignment
                           FOR XML PATH('pitcher'), TYPE
                    )
                    FROM @pitchers t
                    WHERE t.event_key = e.event_key
                    ORDER BY t.alignment ASC
                    FOR XML PATH('team'), TYPE
                )
                FROM @pitchers e
                WHERE e.[date] = d.[date] AND e.league = l.league AND e.alignment = 'away'
                ORDER BY e.start_date_time_EST ASC
                FOR XML PATH('event'), TYPE
            )
            FROM @pitchers l
            WHERE l.[date] = d.[date]
            GROUP BY l.league
            FOR XML PATH('league'), TYPE
        )
        FROM @pitchers d
        GROUP BY d.[date]
        ORDER BY d.[date] ASC
        FOR XML PATH('leagues'), TYPE
    )
	FOR XML PATH('probable-pitchers')


    SET NOCOUNT OFF;
END

GO
