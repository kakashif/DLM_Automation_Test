USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventMatchup_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventMatchup_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 08/12/2014
-- Description: get team matchup
-- Update: 11/10/2014 - John Lin - use SMG_Standings for points scored for/against
--         11/17/2014 - John Lin - differences in pro and college stats
--         02/20/2015 - ikenticus - migrating SMG_Player/Team_Season_Statistics to SMG_Statistics
--         03/02/2015 - pkamat - change column rebounds-total-per-game to rebounds-per-game
--         07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
      
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 

    IF (@event_status <> 'pre-event')
    BEGIN
        SELECT '' AS matchup
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
    
    -- exclude All-Star and Pro Bowl
    DECLARE @ribbon VARCHAR(100)
    
    SELECT @ribbon = schedule
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key

    DECLARE @matchup TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
   	    category VARCHAR(100),
        [column] VARCHAR(100),
        away_header VARCHAR(100),
        home_header VARCHAR(100),
   		away_value VARCHAR(100),
	    away_percent VARCHAR(100),
	    home_value VARCHAR(100),
	    home_percent VARCHAR(100)
    )

    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @matchup (category)
        VALUES ('STARTER')
    
        DECLARE @pitchers TABLE
        (
            team_key VARCHAR(100),
            player_key VARCHAR(100),
            wins VARCHAR(100),
            losses VARCHAR(100),
            era VARCHAR(100)
        )

        INSERT INTO @pitchers (team_key, player_key, wins, losses, era)
        SELECT p.team_key, p.player_key, wins, losses, era
          FROM (SELECT spss.team_key, spss.player_key, spss.[column], spss.value
                  FROM SportsEditDB.dbo.SMG_Statistics spss
                 INNER JOIN SportsDB.dbo.SMG_Transient st
                    ON st.team_key = spss.team_key AND st.player_key = spss.player_key AND st.event_key = @event_key
                 WHERE spss.season_key = @seasonKey AND spss.sub_season_type = 'season-regular' AND
                       spss.team_key IN (@away_key, @home_key) AND spss.[column] IN ('wins', 'losses', 'era')) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (wins, losses, era)) AS p

        UPDATE @matchup
           SET away_header = (SELECT LEFT(sp.first_name, 1) + '. ' + sp.last_name FROM SportsDB.dbo.SMG_Players sp
                               INNER JOIN @pitchers p ON p.player_key = sp.player_key AND p.team_key = @away_key),
               home_header = (SELECT LEFT(sp.first_name, 1) + '. ' + sp.last_name FROM SportsDB.dbo.SMG_Players sp
                               INNER JOIN @pitchers p ON p.player_key = sp.player_key AND p.team_key = @home_key)
         WHERE category = 'STARTER'
                 
        IF (@ribbon IS NOT NULL AND (CHARINDEX('ALL-STAR', @ribbon) > 0 OR CHARINDEX('PRO BOWL', @ribbon) > 0))
        BEGIN
            UPDATE @matchup
               SET away_value = '(0-0) 0.00 era', home_value = '(0-0) 0.00 era'
             WHERE category = 'STARTER'
        END
        ELSE
        BEGIN
            UPDATE @matchup
               SET away_value = (SELECT '(' + wins + '-' + losses + ') ' + era + ' era' FROM @pitchers WHERE team_key = @away_key),
                   home_value = (SELECT '(' + wins + '-' + losses + ') ' + era + ' era' FROM @pitchers WHERE team_key = @home_key)
             WHERE category = 'STARTER'

            INSERT INTO @matchup (category)
            VALUES ('LAST 10'), ('STREAK')

            DECLARE @standings TABLE
            (
                team_key VARCHAR(100),
                l10_wins VARCHAR(100),
                l10_losses VARCHAR(100),
                streak VARCHAR(100)
            )

            INSERT INTO @standings (team_key, l10_wins, l10_losses, streak)
            SELECT p.team_key, [last-ten-games-wins], [last-ten-games-losses], streak
              FROM (SELECT team_key, [column], value
                      FROM SportsEditDB.dbo.SMG_Standings
                     WHERE season_key = @seasonKey AND team_key IN (@away_key, @home_key) AND
                           [column] IN ('last-ten-games-wins', 'last-ten-games-losses', 'streak')) AS s
             PIVOT (MAX(s.value) FOR s.[column] IN ([last-ten-games-wins], [last-ten-games-losses], streak)) AS p

            UPDATE @matchup
               SET away_value = (SELECT l10_wins + '-' + l10_losses FROM @standings WHERE team_key = @away_key),
                   home_value = (SELECT l10_wins + '-' + l10_losses FROM @standings WHERE team_key = @home_key)
             WHERE category = 'LAST 10'

            UPDATE @matchup
               SET away_value = (SELECT streak FROM @standings WHERE team_key = @away_key),
                   home_value = (SELECT streak FROM @standings WHERE team_key = @home_key)
             WHERE category = 'STREAK'
        END               
    END
    ELSE
    BEGIN
        IF (@ribbon IS NULL OR (CHARINDEX('ALL-STAR', @ribbon) = 0 AND CHARINDEX('PRO BOWL', @ribbon) = 0))
        BEGIN
            IF (@leagueName IN ('nba', 'wnba'))
            BEGIN
                INSERT INTO @matchup (category, [column])
                VALUES ('POINTS PER GAME', 'points-scored-for-per-game'),
                       ('FIELD GOAL %', 'field-goals-percentage'),
                       ('REBOUNDS PER GAME', 'rebounds-per-game'),
                       ('ASSISTS PER GAME', 'assists-per-game'),
                       ('STEALS PER GAME', 'steals-per-game'), 
                       ('TURNOVERS PER GAME', 'turnovers-total-per-game'),
                       ('BLOCKS PER GAME', 'blocks-per-game')
            END
            ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
            BEGIN
                INSERT INTO @matchup (category, [column])
                VALUES ('POINTS PER GAME', 'points-scored-total-per-game'),
                       ('FIELD GOAL %', 'field-goals-percentage'),
                       ('REBOUNDS PER GAME', 'rebounds-per-game'),
                       ('ASSISTS PER GAME', 'assists-total-per-game'),
                       ('STEALS PER GAME', 'steals-total-per-game'), 
                       ('TURNOVERS PER GAME', 'turnovers-total-per-game'),
                       ('BLOCKS PER GAME', 'blocks-total-per-game')
            END
            ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
            BEGIN
                INSERT INTO @matchup (category, [column])
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
                INSERT INTO @matchup (category, [column])
                VALUES ('GOALS', 'goals'),
                       ('GOALS ALLOWED', 'goals-allowed'),
                       ('PP GOALS', 'goals-power-play'),
                       ('PP GOALS ALLOWED', 'goals-power-play-allowed'),
                       ('PENALTY KILL %', 'penalty-killing-percentage'),
                       ('PENALTY MINUTES', 'penalty-minutes')
            END


            UPDATE m
               SET m.away_value = stss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
                ON stss.league_key = @league_key AND stss.season_key = @seasonKey AND stss.sub_season_type = 'season-regular' AND
   	               stss.team_key = @away_key AND stss.[column] = m.[column] AND stss.category = 'feed' AND stss.player_key = 'team'
	
            UPDATE m
               SET m.home_value = stss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
                ON stss.league_key = @league_key AND stss.season_key = @seasonKey AND stss.sub_season_type = 'season-regular' AND
                   stss.team_key = @home_key AND stss.[column] = m.[column] AND stss.category = 'feed' AND stss.player_key = 'team'

            -- format
            UPDATE @matchup
               SET away_value = CAST(away_value AS DECIMAL(4, 1)),
                   home_value = CAST(home_value AS DECIMAL(4, 1))
             WHERE [column] in ('rebounds-per-game', 'assists-per-game', 'steals-per-game', 'turnovers-total-per-game',
                                'blocks-per-game', 'points-scored-total-per-game', 'assists-total-per-game',
                                'steals-total-per-game', 'turnovers-total-per-game', 'blocks-total-per-game',
                                'offensive-plays-average-yards-per-game', 'offensive-plays-against-average-yards-per-game',
                                'passes-average-yards-per-game', 'passes-against-average-yards-per-game',
                                'rushes-average-yards-per-game', 'rushing-against-average-yards-per-game')
  
            -- standings
            UPDATE m
               SET m.away_value = ss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Standings ss
                ON ss.season_key = @seasonKey AND ss.team_key = @away_key AND ss.[column] = m.[column]
	         WHERE m.[column] IN ('points-scored-for', 'points-scored-for-per-game', 'points-scored-against', 'points-scored-against-per-game')

            UPDATE m
               SET m.home_value = ss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Standings ss
	            ON ss.season_key = @seasonKey AND ss.team_key = @home_key AND ss.[column] = m.[column]
	         WHERE m.[column] IN ('points-scored-for', 'points-scored-for-per-game', 'points-scored-against', 'points-scored-against-per-game')


            UPDATE @matchup
               SET away_percent = CAST(CAST(away_value AS FLOAT) * 100 / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) AS INT),
                   home_percent = CAST(CAST(home_value AS FLOAT) * 100 / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) AS INT)
        END
    END


    
    SELECT
    (
        SELECT m.category,
               (
                   SELECT m_a.away_header AS header, m_a.away_value AS value, m_a.away_percent AS [percent]
                     FROM @matchup m_a
                    WHERE m_a.id = m.id
                      FOR XML RAW('away'), TYPE
               ),
               (
                   SELECT m_h.home_header AS header, m_h.home_value AS value, m_h.home_percent AS [percent]
                     FROM @matchup m_h
                    WHERE m_h.id = m.id
                      FOR XML RAW('home'), TYPE               
               )
          FROM @matchup m
         ORDER BY m.id ASC
           FOR XML RAW('matchup'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
