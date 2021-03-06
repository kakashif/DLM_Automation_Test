USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventMatchup_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventMatchup_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/10/2014
-- Description: get addional event detail by event status
-- Update: 07/17/2014 - John Lin - update matchup logic
--         10/07/2014 - John Lin - head to head use per game statistics
--         10/14/2014 - John Lin - remove league key from SMG_Standings
--         11/10/2014 - John Lin - use SMG_Standings for points scored for/against
--         11/18/2014 - John Lin - update field goals percentage format
--         02/20/2015 - ikenticus - migrating SMG_Player/Team_Season_Statistics to SMG_Statistics
--         03/02/2015 - pkamat - change column rebounds-total-per-game to rebounds-per-game
--         04/30/2015 - ikenticus: adjusting event_key to handle multiple sources
--         06/23/2015 - John Lin - STATS migration
--	       06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--         09/01/2015 - ikenticus - formatting SDI era for starting pitchers
--         09/23/2015 - John Lin - SDI migration
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
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_name VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_name VARCHAR(100)
      
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@event_status <> 'pre-event')
    BEGIN
        SELECT '' AS matchup
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
    

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
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
   		away VARCHAR(100),
	    home VARCHAR(100)
    )

    INSERT INTO @matchup (category, [column], away, home)
    VALUES ('', '', UPPER(@away_name), UPPER(@home_name))

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
               SET away = '(0-0) 0.00 era', home = '(0-0) 0.00 era'
             WHERE category = 'STARTER'
        END
        ELSE
        BEGIN
            UPDATE @matchup
               SET away = (SELECT '(' + wins + '-' + losses + ') ' + CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR) + ' era' FROM @pitchers WHERE team_key = @away_key),
                   home = (SELECT '(' + wins + '-' + losses + ') ' + CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR) + ' era' FROM @pitchers WHERE team_key = @home_key)
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
               SET away = (SELECT l10_wins + '-' + l10_losses FROM @standings WHERE team_key = @away_key),
                   home = (SELECT l10_wins + '-' + l10_losses FROM @standings WHERE team_key = @home_key)
             WHERE category = 'LAST 10'

            UPDATE @matchup
               SET away = (SELECT streak FROM @standings WHERE team_key = @away_key),
                   home = (SELECT streak FROM @standings WHERE team_key = @home_key)
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
                VALUES ('GOALS', 'goals-per-game'),
                       ('GOALS ALLOWED', 'goalie-goals-against-per-game'),
                       ('SHOTS', 'shots-per-game'),
                       ('SHOTS ALLOWED', 'goalie-shots-against-per-game'),
                       ('PENALTY MINUTES', 'penalty-minutes-per-game')
            END


            UPDATE m
               SET m.away = stss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
                ON stss.league_key = @league_key AND stss.season_key = @seasonKey AND stss.sub_season_type = 'season-regular' AND
   	               stss.team_key = @away_key AND stss.[column] = m.[column] AND stss.category = 'feed' AND stss.player_key = 'team'
	
            UPDATE m
               SET m.home = stss.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
                ON stss.league_key = @league_key AND stss.season_key = @seasonKey AND stss.sub_season_type = 'season-regular' AND
                   stss.team_key = @home_key AND stss.[column] = m.[column] AND stss.category = 'feed' AND stss.player_key = 'team'

            -- format
            UPDATE @matchup
               SET away = CAST(away AS FLOAT) * 100,
                   home = CAST(home AS FLOAT) * 100
             WHERE [column] in ('field-goals-percentage')
        END
    END


    
    SELECT
    (
        SELECT category, away, home, away_header, home_header
          FROM @matchup
         ORDER BY id ASC
           FOR XML RAW('matchup'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
