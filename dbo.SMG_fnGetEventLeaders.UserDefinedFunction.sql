USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetEventLeaders]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetEventLeaders] (
    @leagueKey VARCHAR(100),
    @xml_events  XML
)
RETURNS @leaders TABLE (
    stat_order   INT IDENTITY(1, 1),
    event_key    VARCHAR(100),
    team_key     VARCHAR(100),
    player_key   VARCHAR(100),
    category     VARCHAR(100),
    player_value VARCHAR(100),
    stat_value   VARCHAR(100)
)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/11/2013
-- Description:	get MLB event leaders
-- Update: 07/09/2013 - use XML to pass in event keys
-- =============================================
BEGIN
/* DEPRECATED

    DECLARE @events TABLE
    (
        event_key VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        event_key  VARCHAR(100),
	    team_key   VARCHAR(100),
        player_key VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        event_key  VARCHAR(100),
	    team_key   VARCHAR(100),
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    DECLARE @teams TABLE
    (
        id        INT IDENTITY(1, 1) PRIMARY KEY,
        event_key VARCHAR(100),
        team_key  VARCHAR(100)
    )
    DECLARE @id INT = 1
    DECLARE @max INT
    DECLARE @event_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    
    INSERT INTO @events (event_key)
    SELECT node.value('(@event_key)[1]', 'varchar(100)')
      FROM @xml_events.nodes('/events') AS SMG(node)

    DECLARE @assists VARCHAR(100)
    
    IF (@leagueKey = 'l.mlb.com')
    BEGIN
        DECLARE @baseball TABLE
	    (
	        event_key          VARCHAR(100),
            team_key           VARCHAR(100),
            player_key         VARCHAR(100),
	        [event-credit]     VARCHAR(100),
            era                VARCHAR(100),
            [wins-season]      VARCHAR(100),
            [losses-season]    VARCHAR(100),
            [saves-season]	   VARCHAR(100),    
            [home-runs]        VARCHAR(100),
            [season-home-runs] VARCHAR(100),
	        last_name          VARCHAR(100)
	    )
        -- PITCHING
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_MLB sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] = 'event-credit' AND sess.value IN ('win', 'loss', 'save')

        -- HR
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_MLB sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] = 'home-runs' AND sess.value <> '0'

        INSERT INTO @stats (event_key, team_key, player_key, [column], value)
        SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_MLB sess
            ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
               sess.[column] IN ('event-credit', 'era', 'wins-season', 'losses-season', 'saves-season', 'home-runs', 'season-home-runs')

        INSERT INTO @baseball
        SELECT p.event_key, p.team_key, p.player_key, [event-credit], era, [wins-season], [losses-season], [saves-season], [home-runs], [season-home-runs], NULL
          FROM (SELECT event_key, team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([event-credit], era, [wins-season], [losses-season], [saves-season], [home-runs], [season-home-runs])) AS p

        UPDATE b
    	   SET b.last_name = dn.last_name
	      FROM @baseball b
    	 INNER JOIN dbo.persons p
            ON p.person_key = b.player_key AND p.publisher_id = 2
         INNER JOIN dbo.display_names dn
            ON dn.entity_id = p.id AND dn.entity_type = 'persons'
    
        -- PITCHING
        INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
        SELECT event_key, team_key, player_key, 'PITCHING', UPPER(LEFT([event-credit], 1)) + ': ' + last_name,
               (CASE
                   WHEN [event-credit] = 'save' THEN '(' + [saves-season] + ')'
                   ELSE '(' + [wins-season] + '-' + [losses-season] + ') ' + era + ' era'
               END)
          FROM @baseball
         WHERE [event-credit] IN ('win', 'loss', 'save')
         ORDER BY (CASE
                      WHEN [event-credit] = 'win' THEN 1
                      WHEN [event-credit] = 'loss' THEN 2
                      ELSE 3
                  END) ASC

        -- HR
        INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
        SELECT event_key, team_key, player_key, 'HR', last_name, [home-runs] + ' (' + [season-home-runs] + ')'
          FROM @baseball
         WHERE [home-runs] IS NOT NULL AND [home-runs] <> '0'
         ORDER BY last_name ASC
    END
    ELSE IF (@leagueKey = 'l.mlsnet.com')
    BEGIN
        DECLARE @soccer TABLE
	    (
	        event_key          VARCHAR(100),
            team_key           VARCHAR(100),
            player_key         VARCHAR(100),
            [goals-total]      VARCHAR(100),
            [assists-total]    VARCHAR(100),
	        last_name          VARCHAR(100)
	    )
        DECLARE @goals VARCHAR(100)

        -- GOALS
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_MLS sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] = 'goals-total' AND sess.value <> '0'

        -- ASSISTS
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_MLS sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] = 'assists-total' AND sess.value <> '0'

        INSERT INTO @stats (event_key, team_key, player_key, [column], value)
        SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_MLS sess
            ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
               sess.[column] IN ('goals-total', 'assists-total')

        INSERT INTO @soccer
        SELECT p.event_key, p.team_key, p.player_key, [goals-total], [assists-total], NULL
          FROM (SELECT event_key, team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([goals-total], [assists-total])) AS p

        UPDATE s
    	   SET s.last_name = dn.last_name
	      FROM @soccer s
    	 INNER JOIN dbo.persons p
            ON p.person_key = s.player_key AND p.publisher_id = 2
         INNER JOIN dbo.display_names dn
            ON dn.entity_id = p.id AND dn.entity_type = 'persons'
    
        INSERT INTO @teams (event_key, team_key)
        SELECT event_key, team_key
          FROM @soccer
         GROUP BY event_key, team_key

        SELECT @max = MAX(id)
          FROM @teams
          
        WHILE (@id <= @max)
        BEGIN
            SELECT @event_key = event_key, @team_key = team_key
              FROM @teams
             WHERE id = @id

            -- GOALS
            SELECT TOP 1 @goals = [goals-total]
              FROM @soccer
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([goals-total] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'GOALS', last_name, @goals + ' goals'
              FROM @soccer
             WHERE event_key = @event_key AND team_key = @team_key AND [goals-total] = @goals
             ORDER BY last_name ASC

            -- ASSISTS
            SELECT TOP 1 @assists = [assists-total]
              FROM @soccer
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([assists-total] AS INT) DESC

            IF (@assists <> '0')
            BEGIN
                INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
                SELECT event_key, team_key, player_key, 'ASSISTS', last_name, @assists + ' ast'
                  FROM @soccer
                 WHERE event_key = @event_key AND team_key = @team_key AND [assists-total] = @assists
                 ORDER BY last_name ASC
            END
                             
            SET @id = @id + 1
        END
    END
    ELSE IF (@leagueKey IN ('l.nba.com', 'l.ncaa.org.mbasket', 'l.ncaa.org.wbasket', 'l.wnba.com'))
    BEGIN
        DECLARE @basketball TABLE
	    (
	        event_key               VARCHAR(100),
            team_key                VARCHAR(100),
            player_key              VARCHAR(100),
	        [points-scored-total]   VARCHAR(100),
	        [field-goals-attempted] VARCHAR(100),
	        [field-goals-made]      VARCHAR(100),
	        [free-throws-attempted] VARCHAR(100),
	        [free-throws-made]      VARCHAR(100),
            [rebounds-total]        VARCHAR(100),
            [assists-total]         VARCHAR(100),
	        last_name               VARCHAR(100)
	    )
        DECLARE @points VARCHAR(100)
        DECLARE @rebounds VARCHAR(100)

        IF (@leagueKey = 'l.ncaa.org.mbasket')
        BEGIN
            -- POINTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAB sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'points-scored-total' AND sess.value <> '0'

            -- REBOUNDS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAB sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rebounds-total' AND sess.value <> '0'

            -- ASSISTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAB sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'assists-total' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAB sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('points-scored-total', 'field-goals-attempted', 'field-goals-made', 'free-throws-attempted',
                                     'free-throws-made','rebounds-total', 'assists-total')
        END
        ELSE IF (@leagueKey = 'l.ncaa.org.wbasket')
        BEGIN
            -- POINTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAW sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'points-scored-total' AND sess.value <> '0'

            -- REBOUNDS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAW sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rebounds-total' AND sess.value <> '0'

            -- ASSISTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAW sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'assists-total' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAW sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('points-scored-total', 'field-goals-attempted', 'field-goals-made', 'free-throws-attempted',
                                     'free-throws-made','rebounds-total', 'assists-total')
        END
        ELSE IF (@leagueKey = 'l.wnba.com')
        BEGIN
            -- POINTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_WNBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'points-scored-total' AND sess.value <> '0'

            -- REBOUNDS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_WNBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rebounds-total' AND sess.value <> '0'

            -- ASSISTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_WNBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'assists-total' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_WNBA sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('points-scored-total', 'field-goals-attempted', 'field-goals-made', 'free-throws-attempted',
                                     'free-throws-made','rebounds-total', 'assists-total')
        END
        ELSE
        BEGIN
            -- POINTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'points-scored-total' AND sess.value <> '0'

            -- REBOUNDS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rebounds-total' AND sess.value <> '0'

            -- ASSISTS
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NBA sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'assists-total' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NBA sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('points-scored-total', 'field-goals-attempted', 'field-goals-made', 'free-throws-attempted',
                                     'free-throws-made','rebounds-total', 'assists-total')
        END
        
        INSERT INTO @basketball
        SELECT p.event_key, p.team_key, p.player_key, [points-scored-total], [field-goals-attempted], [field-goals-made],
               [free-throws-attempted], [free-throws-made], [rebounds-total], [assists-total], NULL
          FROM (SELECT event_key, team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([points-scored-total], [field-goals-attempted], [field-goals-made],
                                                [free-throws-attempted], [free-throws-made], [rebounds-total], [assists-total])) AS p

        UPDATE b
    	   SET b.last_name = dn.last_name
	      FROM @basketball b
    	 INNER JOIN dbo.persons p
            ON p.person_key = b.player_key AND p.publisher_id = 2
         INNER JOIN dbo.display_names dn
            ON dn.entity_id = p.id AND dn.entity_type = 'persons'

        INSERT INTO @teams (event_key, team_key)
        SELECT event_key, team_key
          FROM @basketball
         GROUP BY event_key, team_key

        SELECT @max = MAX(id)
          FROM @teams
          
        WHILE (@id <= @max)
        BEGIN
            SELECT @event_key = event_key, @team_key = team_key
              FROM @teams
             WHERE id = @id

            -- POINTS
            SELECT TOP 1 @points = [points-scored-total]
              FROM @basketball
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([points-scored-total] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'POINTS', last_name,                   
                   (CASE
                       WHEN [field-goals-attempted] <> '0' AND [free-throws-attempted] <> '0' THEN @points + ' pts, ' +
                           CAST(ROUND(CAST([field-goals-made] AS FLOAT) / CAST([field-goals-attempted] AS FLOAT) * 100, 0) AS VARCHAR(100)) + ' fg%, ' +
                           CAST(ROUND(CAST([free-throws-made] AS FLOAT) / CAST([free-throws-attempted] AS FLOAT) * 100, 0) AS VARCHAR(100)) + ' ft%'
                       WHEN [field-goals-attempted] <> '0' THEN @points + ' pts, ' +
                           CAST(ROUND(CAST([field-goals-made] AS FLOAT) / CAST([field-goals-attempted] AS FLOAT) * 100, 0) AS VARCHAR(100)) + ' fg%'
                       WHEN [free-throws-attempted] <> '0' THEN @points + ' pts, ' +
                           CAST(ROUND(CAST([free-throws-made] AS FLOAT) / CAST([free-throws-attempted] AS FLOAT) * 100, 0) AS VARCHAR(100)) + ' ft%'
                       ELSE @points + ' pts'
                   END)
              FROM @basketball
             WHERE event_key = @event_key AND team_key = @team_key AND [points-scored-total] = @points

            -- REBOUNDS
            SELECT TOP 1 @rebounds = [rebounds-total]
              FROM @basketball
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([rebounds-total] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'REBOUNDS', last_name, @rebounds + ' reb'
              FROM @basketball
             WHERE event_key = @event_key AND team_key = @team_key AND [rebounds-total] = @rebounds
             ORDER BY last_name ASC

            -- ASSISTS
            SELECT TOP 1 @assists = [assists-total]
              FROM @basketball b
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([assists-total] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'ASSISTS', last_name, @assists + ' ast'
              FROM @basketball
             WHERE event_key = @event_key AND team_key = @team_key AND [assists-total] = @assists
             ORDER BY last_name ASC
                             
            SET @id = @id + 1
        END
    END
    ELSE IF (@leagueKey IN ('l.nfl.com', 'l.ncaa.org.mfoot'))
    BEGIN
        DECLARE @football TABLE
	    (
	        event_key               VARCHAR(100),
            team_key                VARCHAR(100),
            player_key              VARCHAR(100),
	        [passes-yards-gross]    VARCHAR(100),
	        [passes-attempts]       VARCHAR(100),
	        [passes-completions]    VARCHAR(100),
	        [passes-touchdowns]     VARCHAR(100),
	        [passes-interceptions]  VARCHAR(100),	        
            [rushes-yards]          VARCHAR(100),
            [rushes-attempts]       VARCHAR(100),
            [rushes-touchdowns]     VARCHAR(100),
            [receptions-yards]      VARCHAR(100),
            [receptions-total]      VARCHAR(100),
            [receptions-touchdowns] VARCHAR(100),            
	        last_name               VARCHAR(100)
	    )
        DECLARE @passing   VARCHAR(100)
        DECLARE @rushing   VARCHAR(100)
        DECLARE @receiving VARCHAR(100)

        IF (@leagueKey = 'l.ncaa.org.mfoot')
        BEGIN
            -- PASSING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAF sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'passes-yards-gross' AND sess.value <> '0'

            -- RUSHING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAF sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rushes-yards' AND sess.value <> '0'

            -- RECEIVING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAF sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'receptions-yards' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NCAAF sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('passes-yards-gross', 'passes-attempts', 'passes-completions', 'passes-touchdowns',
                                     'passes-interceptions', 'rushes-yards', 'rushes-attempts', 'rushes-touchdowns',
                                     'receptions-yards', 'receptions-total', 'receptions-touchdowns')
        END
        ELSE
        BEGIN
            -- PASSING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NFL sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'passes-yards-gross' AND sess.value <> '0'

            -- RUSHING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NFL sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'rushes-yards' AND sess.value <> '0'

            -- RECEIVING
            INSERT INTO @players (event_key, team_key, player_key)
            SELECT sess.event_key, sess.team_key, sess.player_key
              FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NFL sess
             INNER JOIN @events e
                ON e.event_key = sess.event_key
             WHERE sess.[column] = 'receptions-yards' AND sess.value <> '0'

            INSERT INTO @stats (event_key, team_key, player_key, [column], value)
            SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
              FROM @players p
             INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NFL sess
                ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
                   sess.[column] IN ('passes-yards-gross', 'passes-attempts', 'passes-completions', 'passes-touchdowns',
                                     'passes-interceptions', 'rushes-yards', 'rushes-attempts', 'rushes-touchdowns',
                                     'receptions-yards', 'receptions-total', 'receptions-touchdowns')
        END
        
        INSERT INTO @football
        SELECT p.event_key, p.team_key, p.player_key, [passes-yards-gross], [passes-attempts], [passes-completions],
               [passes-touchdowns], [passes-interceptions], [rushes-yards], [rushes-attempts], [rushes-touchdowns],
               [receptions-yards], [receptions-total], [receptions-touchdowns], NULL
          FROM (SELECT event_key, team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([passes-yards-gross], [passes-attempts], [passes-completions], [passes-touchdowns],
                                                [passes-interceptions], [rushes-yards], [rushes-attempts], [rushes-touchdowns],
                                                [receptions-yards], [receptions-total], [receptions-touchdowns])) AS p

        UPDATE f
    	   SET f.last_name = dn.last_name
	      FROM @football f
    	 INNER JOIN dbo.persons p
            ON p.person_key = f.player_key AND p.publisher_id = 2
         INNER JOIN dbo.display_names dn
            ON dn.entity_id = p.id AND dn.entity_type = 'persons'

        INSERT INTO @teams (event_key, team_key)
        SELECT event_key, team_key
          FROM @football
         GROUP BY event_key, team_key

        SELECT @max = MAX(id)
          FROM @teams
          
        WHILE (@id <= @max)
        BEGIN
            SELECT @event_key = event_key, @team_key = team_key
              FROM @teams
             WHERE id = @id

            -- PASSING
            SELECT TOP 1 @passing = [passes-yards-gross]
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([passes-yards-gross] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'PASSING', last_name,
                   [passes-completions] + '/' + [passes-attempts] + ', ' + @passing + ' yds, ' + [passes-touchdowns] + ' tds, ' + [passes-interceptions] + ' int'
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key AND [passes-yards-gross] = @passing

            -- RUSHING
            SELECT TOP 1 @rushing = [rushes-yards]
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([rushes-yards] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'RUSHING', last_name,
                   [rushes-attempts] + ' car, ' + @rushing + ' yds, ' + [rushes-touchdowns] + ' tds'
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key AND [rushes-yards] = @rushing
             ORDER BY last_name ASC

            -- RECEIVING
            SELECT TOP 1 @receiving = [receptions-yards]
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key
             ORDER BY CAST([receptions-yards] AS INT) DESC

            INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
            SELECT event_key, team_key, player_key, 'RECEIVING', last_name,
                   [receptions-total] + ' rec, ' + @receiving + ' yds, ' + [receptions-touchdowns] + ' tds'
              FROM @football
             WHERE event_key = @event_key AND team_key = @team_key AND [receptions-yards] = @receiving    
             ORDER BY last_name ASC
                             
            SET @id = @id + 1
        END
    END
    ELSE IF (@leagueKey = 'l.nhl.com')
    BEGIN
        DECLARE @hockey TABLE
	    (
	        event_key                  VARCHAR(100),
            team_key                   VARCHAR(100),
            player_key                 VARCHAR(100),
	        saves                      VARCHAR(100),
            [goaltender-wins-season]   VARCHAR(100),
            [goaltender-losses-season] VARCHAR(100),
            score	                   VARCHAR(100),    
            [goals-cumulative]         VARCHAR(100),
	        last_name                  VARCHAR(100)
	    )
        -- GOAL TENDING
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NHL sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] IN ('goaltender-wins', 'goaltender-losses', 'goaltender-losses-overtime') AND sess.value <> '0'
         
        -- SCORING
        INSERT INTO @players (event_key, team_key, player_key)
        SELECT sess.event_key, sess.team_key, sess.player_key
          FROM SportsEditDB.dbo.SMG_Event_Season_Statistics_NHL sess
         INNER JOIN @events e
            ON e.event_key = sess.event_key
         WHERE sess.[column] = 'score' AND sess.value <> '0'

        INSERT INTO @stats (event_key, team_key, player_key, [column], value)
        SELECT p.event_key, p.team_key, p.player_key, sess.[column], sess.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Event_Season_Statistics_NHL sess
            ON sess.event_key = p.event_key AND sess.player_key = p.player_key AND
               sess.[column] IN ('saves', 'goaltender-wins-season', 'goaltender-losses-season', 'score', 'goals-cumulative')
            
        INSERT INTO @hockey
        SELECT p.event_key, p.team_key, p.player_key, saves, [goaltender-wins-season], [goaltender-losses-season], score, [goals-cumulative], NULL
          FROM (SELECT event_key, team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (saves, [goaltender-wins-season], [goaltender-losses-season], score, [goals-cumulative])) AS p

        UPDATE h
    	   SET h.last_name = dn.last_name
	      FROM @hockey h
    	 INNER JOIN dbo.persons p
            ON p.person_key = h.player_key AND p.publisher_id = 2
         INNER JOIN dbo.display_names dn
            ON dn.entity_id = p.id AND dn.entity_type = 'persons'
    
        -- GOAL TENDING
        INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
        SELECT event_key, team_key, player_key, 'GOAL_TENDING', last_name,
               saves + ' sv (' + [goaltender-wins-season] + '-' + [goaltender-losses-season] + ')'
          FROM @hockey
         WHERE saves IS NOT NULL

        -- SCORING
        INSERT INTO @leaders (event_key, team_key, player_key, category, player_value, stat_value)            
        SELECT event_key, team_key, player_key, 'SCORING', last_name, score + ' (' + [goals-cumulative] + ')'
          FROM @hockey
         WHERE score IS NOT NULL
         ORDER BY last_name ASC
    END
*/
    RETURN
END

GO
