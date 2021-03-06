USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_baseball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Player_baseball_XML]
    @playerId INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 04/29/2015
  -- Description: get baseball player statistics for USCP
  -- Update: 05/06/2015 - John Lin - add salary
  --         08/28/2015 - John Lin - add team slug
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    DECLARE @sub_season_type VARCHAR(100) = 'pre-season'
    DECLARE @team_key VARCHAR(100)
    DECLARE @player_key VARCHAR(100)

    SELECT TOP 1 @player_key = player_key
      FROM dbo.SMG_Rosters
     WHERE league_key = @league_key AND team_key = @team_key AND player_key LIKE '%' + CAST(@playerId AS VARCHAR)

    IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Statistics
                       WHERE league_key = @league_key AND sub_season_type = 'season-regular' AND team_key = @team_key AND player_key = @player_key)
    BEGIN
        SET @sub_season_type = 'season-regular'
    END

    DECLARE @player TABLE
    (
        player_key VARCHAR(100),
        uniform_number VARCHAR(100),
        position VARCHAR(100),
        height VARCHAR(100),
        [weight] INT,
        head_shot VARCHAR(200),
        [filename] VARCHAR(100),
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        age INT,
        bats VARCHAR(100),
        birth VARCHAR(100),
        throws VARCHAR(100),
        salary VARCHAR(100)
    )
    INSERT INTO @player (player_key, uniform_number, position, height, [weight], head_shot, [filename])
    SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename]
      FROM dbo.SMG_Rosters
     WHERE league_key = @league_key AND team_key = @team_key AND player_key = @player_key AND phase_status <> 'delete'

    UPDATE p
       SET p.first_name = sp.first_name, p.last_name = sp.last_name,
           p.age = DATEDIFF(YY, sp.date_of_birth, GETDATE()), 
           p.bats = sp.shooting_batting_hand, p.birth = sp.birth_place, p.throws = sp.throwing_hand
      FROM @player p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key

    -- embargo latest season
	DECLARE @embargo_season INT
	DECLARE @salary MONEY

	SELECT @embargo_season = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = 'mlb' AND page = 'salaries'

	IF (@embargo_season IS NULL)
	BEGIN
		SET @embargo_season = YEAR(GETDATE())
	END

	SELECT TOP 1 @salary = salary
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE season_key <= @embargo_season AND player_key = @player_key
	 ORDER BY season_key DESC

    UPDATE @player
       SET salary = '$' + REPLACE(CONVERT(VARCHAR, @salary, 1), '.00', '')

    UPDATE @player
       SET uniform_number = ''           
     WHERE uniform_number IS NULL OR uniform_number = 0

    UPDATE @player
       SET head_shot = 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
     WHERE head_shot IS NOT NULL AND [filename] IS NOT NULL

    DECLARE @baseball TABLE
    (
        position VARCHAR(100),
        [events-played] INT,
        [events-started] INT,
        -- pitching
        [games-pitched] INT,
        [games-complete] VARCHAR(100),
        [games-finished] VARCHAR(100),
        [innings-pitched] VARCHAR(100),
        [shutouts] VARCHAR(100),
        pitcher_hits INT,
        earned_run_average VARCHAR(100),
        [runs-allowed] VARCHAR(100),
        [home-runs-allowed] VARCHAR(100), 
        [earned-runs] VARCHAR(100),
        [pitching-bases-on-balls] VARCHAR(100),
        pitcher_strikeouts INT,
        [strikeouts-looking] VARCHAR(100), 
        [strikeouts-per-9-innings] VARCHAR(100),
        [errors-wild-pitch] VARCHAR(100),
        [balks] VARCHAR(100),
        [wins] VARCHAR(100),
        [losses] VARCHAR(100),
        [saves] VARCHAR(100),
        [saves-blown] VARCHAR(100),
        [whip] VARCHAR(100),
        -- batting
        [at-bats] VARCHAR(100),
        [plate-appearances] VARCHAR(100),
        [runs-scored] VARCHAR(100),
        [hits] VARCHAR(100),
        [doubles] VARCHAR(100),
        [triples] VARCHAR(100),
        [home-runs] VARCHAR(100),
        [rbi] VARCHAR(100),
        [total-bases] VARCHAR(100),
        [bases-on-balls] VARCHAR(100),
        [strikeouts] VARCHAR(100),
        [stolen-bases] VARCHAR(100),
        [stolen-bases-caught] VARCHAR(100),
        [average] VARCHAR(100),
        [on-base-percentage] VARCHAR(100),
        [slugging-percentage] VARCHAR(100),
        [on-base-plus-slugging-percentage] VARCHAR(100),
        [sacrifices] VARCHAR(100),
        [sac-flies] VARCHAR(100),
        [hit-by-pitch] VARCHAR(100),
        [errors-passed-ball] VARCHAR(100),
        [errors] VARCHAR(100),
        [reached-base-defensive-interference] VARCHAR(100),
        [grounded-into-double-play] VARCHAR(100),
        -- extra
        pitcher_games_played INT,
        pitcher_games_started INT
    )        
    DECLARE @stats TABLE
    (
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )

    INSERT INTO @stats ([column], value)
    SELECT [column], value
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND sub_season_type = @sub_season_type AND team_key = @team_key AND player_key = @player_key

    INSERT INTO @baseball([events-played], [events-started], [games-pitched], [games-complete],
                          [games-finished], [innings-pitched], [shutouts], pitcher_hits, earned_run_average,
                          [runs-allowed], [home-runs-allowed], [earned-runs], [pitching-bases-on-balls],
                          pitcher_strikeouts, [strikeouts-looking], [strikeouts-per-9-innings],
                          [errors-wild-pitch], [balks], [wins], [losses], [saves], [saves-blown], [whip],
                          [at-bats], [plate-appearances], [runs-scored], [hits], [doubles], [triples],
                          [home-runs], [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases],
                          [stolen-bases-caught], [average], [on-base-percentage], [slugging-percentage],
                          [on-base-plus-slugging-percentage], [sacrifices], [sac-flies], [hit-by-pitch],
                          [errors-passed-ball], [errors], [reached-base-defensive-interference],
                          [grounded-into-double-play],
                          pitcher_games_played, pitcher_games_started)
    SELECT [events-played], [events-started], games_played, [games-complete],
           [games-finished], [innings-pitched], [shutouts], pitcher_hits, earned_run_average,
           [runs-allowed], [home-runs-allowed], [earned-runs], [pitching-bases-on-balls],
           pitcher_strikeouts, [strikeouts-looking], [strikeouts-per-9-innings],
           [errors-wild-pitch], [balks], [wins], [losses], [saves], [saves-blown], [whip],
           [at-bats], [plate-appearances], [runs-scored], [hits], [doubles], [triples],
           [home-runs], [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases],
           [stolen-bases-caught], [average], [on-base-percentage], [slugging-percentage],
           [on-base-plus-slugging-percentage], [sacrifices], [sac-flies], [hit-by-pitch],
           [errors-passed-ball], [fielding-errors], [reached-base-defensive-interference],
           [grounded-into-double-play],
           pitcher_games_played, pitcher_games_started
      FROM (SELECT [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [events-started], games_played, [games-complete],
                                            [games-finished], [innings-pitched], [shutouts], pitcher_hits, earned_run_average,
                                            [runs-allowed], [home-runs-allowed], [earned-runs], [pitching-bases-on-balls],
                                            pitcher_strikeouts, [strikeouts-looking], [strikeouts-per-9-innings],
                                            [errors-wild-pitch], [balks], [wins], [losses], [saves], [saves-blown], [whip],
                                            [at-bats], [plate-appearances], [runs-scored], [hits], [doubles], [triples],
                                            [home-runs], [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases],
                                            [stolen-bases-caught], [average], [on-base-percentage], [slugging-percentage],
                                            [on-base-plus-slugging-percentage], [sacrifices], [sac-flies], [hit-by-pitch],
                                            [errors-passed-ball], [fielding-errors],  [reached-base-defensive-interference],
                                            [grounded-into-double-play],
                                            pitcher_games_played, pitcher_games_started)) AS p

    UPDATE @baseball
       SET position = (SELECT position FROM @player WHERE player_key = @player_key)     

    UPDATE @baseball
       SET [events-played] = ISNULL([events-played], 0),
           [events-started] = ISNULL([events-started], 0),        
           [at-bats] = ISNULL([at-bats], ''),
           [plate-appearances] = ISNULL([plate-appearances], ''),
           [runs-scored] = ISNULL([runs-scored], 0),
           [hits] = ISNULL([hits], 0),
           [doubles] = ISNULL([doubles], 0),
           [triples] = ISNULL([triples], 0),
           [home-runs] = ISNULL([home-runs], 0),
           [rbi] = ISNULL([rbi], 0),
           [total-bases] = ISNULL([total-bases], 0),
           [bases-on-balls] = ISNULL([bases-on-balls], 0),
           [strikeouts] = ISNULL([strikeouts], 0),
           [stolen-bases] = ISNULL([stolen-bases], 0),
           [stolen-bases-caught] = ISNULL([stolen-bases-caught], 0),
           [average] = ISNULL([average], ''),
           [on-base-percentage] = ISNULL([on-base-percentage], ''),
           [slugging-percentage] = ISNULL([slugging-percentage], ''),
           [on-base-plus-slugging-percentage] = ISNULL([on-base-plus-slugging-percentage], ''),
           [sacrifices] = ISNULL([sacrifices], 0),
           [sac-flies] = ISNULL([sac-flies], 0),
           [hit-by-pitch] = ISNULL([hit-by-pitch], 0),
           [errors-passed-ball] = ISNULL([errors-passed-ball], 0),
           [errors] = ISNULL([errors], 0),
           [reached-base-defensive-interference] = ISNULL([reached-base-defensive-interference], 0),
           [grounded-into-double-play] = ISNULL([grounded-into-double-play], 0)
            
    UPDATE @baseball
       SET [events-started] = ISNULL(pitcher_games_started, 0),
           [games-pitched] = ISNULL(pitcher_games_played, 0),
           [games-complete] = ISNULL([games-complete], 0),
           [games-finished] = ISNULL([games-finished], ''),
           [innings-pitched] = ISNULL([innings-pitched], ''),
           [shutouts] = ISNULL([shutouts], ''),
           pitcher_hits = ISNULL(pitcher_hits, 0),
           earned_run_average = ISNULL(earned_run_average, ''),
           [runs-allowed] = ISNULL([runs-allowed], ''),
           [home-runs-allowed] = ISNULL([home-runs-allowed], ''),
           [earned-runs] = ISNULL([earned-runs], ''),
           [pitching-bases-on-balls] = ISNULL([pitching-bases-on-balls], ''),
           pitcher_strikeouts = ISNULL(pitcher_strikeouts, 0),
           [strikeouts-looking] = ISNULL([strikeouts-looking], ''),
           [strikeouts-per-9-innings] = ISNULL([strikeouts-per-9-innings], ''),
           [errors-wild-pitch] = ISNULL([errors-wild-pitch], ''),
           [balks] = ISNULL([balks], ''),
           [wins] = ISNULL([wins], ''),
           [losses] = ISNULL([losses], ''),
           [saves] = ISNULL([saves], ''),
           [saves-blown] = ISNULL([saves-blown], ''),
           [whip] = ISNULL([whip], '')
     WHERE position IN ('SP', 'RP')

    UPDATE @baseball
       SET average = REPLACE(ROUND(CAST(average AS FLOAT), 3), '0.', '.')
     WHERE average IS NOT NULL

    UPDATE @baseball
       SET average = average + '00'
     WHERE average IS NOT NULL AND LEN(average) = 2

    UPDATE @baseball
       SET average = average + '0'
     WHERE average IS NOT NULL AND LEN(average) = 3

    UPDATE @baseball
       SET [on-base-percentage] = REPLACE(ROUND(CAST([on-base-percentage] AS FLOAT), 3), '0.', '.')
     WHERE [on-base-percentage] IS NOT NULL

    UPDATE @baseball
       SET [on-base-percentage] = [on-base-percentage] + '00'
     WHERE [on-base-percentage] IS NOT NULL AND LEN([on-base-percentage]) = 2

    UPDATE @baseball
       SET [on-base-percentage] = [on-base-percentage] + '0'
     WHERE [on-base-percentage] IS NOT NULL AND LEN([on-base-percentage]) = 3

    UPDATE @baseball
       SET [slugging-percentage] = REPLACE(ROUND(CAST([slugging-percentage] AS FLOAT), 3), '0.', '.')
     WHERE [slugging-percentage] IS NOT NULL

    UPDATE @baseball
       SET [slugging-percentage] = [slugging-percentage] + '00'
     WHERE [slugging-percentage] IS NOT NULL AND LEN([slugging-percentage]) = 2

    UPDATE @baseball
       SET [slugging-percentage] = [slugging-percentage] + '0'
     WHERE [slugging-percentage] IS NOT NULL AND LEN([slugging-percentage]) = 3

    UPDATE @baseball
       SET [on-base-plus-slugging-percentage] = REPLACE(ROUND(CAST([on-base-plus-slugging-percentage] AS FLOAT), 3), '0.', '.')
     WHERE [on-base-plus-slugging-percentage] IS NOT NULL

    UPDATE @baseball
       SET [on-base-plus-slugging-percentage] = [on-base-plus-slugging-percentage] + '00'
     WHERE [on-base-plus-slugging-percentage] IS NOT NULL AND LEN([on-base-plus-slugging-percentage]) = 2

    UPDATE @baseball
       SET [on-base-plus-slugging-percentage] = [on-base-plus-slugging-percentage] + '0'
     WHERE [on-base-plus-slugging-percentage] IS NOT NULL AND LEN([on-base-plus-slugging-percentage]) = 3



    SELECT
    (
        SELECT uniform_number, position, height, [weight], head_shot, first_name, last_name, age, birth, throws, bats, salary
          FROM @player
         WHERE player_key = @player_key
           FOR XML RAW('player'), TYPE
    ),
    (
        SELECT [events-played], [events-started], [games-pitched], [games-complete],
               [games-finished], [innings-pitched], [shutouts], pitcher_hits AS 'pitching-hits', earned_run_average AS era,
               [runs-allowed], [home-runs-allowed], [earned-runs], [pitching-bases-on-balls],
               pitcher_strikeouts AS 'pitching-strikeouts', [strikeouts-looking], [strikeouts-per-9-innings],
               [errors-wild-pitch], [balks], [wins], [losses], [saves], [saves-blown], [whip]
          FROM @baseball
         WHERE position IN ('SP', 'RP')
           FOR XML RAW('pitching'), TYPE
    ),
    (
        SELECT [at-bats], [plate-appearances], [runs-scored], [hits], [doubles], [triples],
               [home-runs], [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases],
               [stolen-bases-caught], [average], [on-base-percentage],
               [slugging-percentage], [on-base-plus-slugging-percentage], [sacrifices],
               [sac-flies], [hit-by-pitch], [errors-passed-ball], [errors], 
               [reached-base-defensive-interference], [grounded-into-double-play]
          FROM @baseball
           FOR XML RAW('batting'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
