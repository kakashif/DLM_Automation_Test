USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Statistics_football_team_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Statistics_football_team_XML]
   @leagueName    VARCHAR(100),
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/07/2013
  -- Description: get NFL team statistics
  -- Update: 07/29/2013 - John Lin - exclude team column
  --         08/15/2013 - John Lin - view all bug fix
  --         09/25/2013 - John Lin - pre calculation
  --         01/08/2015 - John Lin - change team_key from league-average to l.nfl.com
  --         02/20/2015 - ikenticus - migrating SMG_Player/Team_Season_Statistics to SMG_Statistics
  --         07/27/2015 - John Lin - STATS migration
  --         08/19/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    DECLARE @stats TABLE
    (
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    INSERT INTO @stats (category, [column], value)
    SELECT category, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND team_key = @teamKey AND player_key = 'team'

    DECLARE @tables TABLE
    (
        ribbon VARCHAR(100),
        [column] VARCHAR(100),
        sub_ribbon VARCHAR(100),
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [order] INT
    )
    DECLARE @football TABLE
    (
        category VARCHAR(100),
        games_played INT,
        -- offense
        [total-yards] INT,
        [total-yards-per-game] VARCHAR(100),
        passing_net_yards INT,
        [passing-net-yards-per-game] VARCHAR(100),
        rushing_net_yards INT,
        [rushing-net-yards-per-game] VARCHAR(100),
        points VARCHAR(100),
        [points-per-game] VARCHAR(100),
        passing_plays_attempted INT,
        passing_plays_completed INT,
        [passing-percentage] VARCHAR(100),
        [passing-net-yards-per-attempted] VARCHAR(100),
        passing_longest_yards INT,
        passing_touchdowns INT,
        passing_plays_intercepted INT,
        passer_rating VARCHAR(100),
        rushing_plays INT,
        [rushing-net-yards-per-play] VARCHAR(100),
        rushing_longest_yards INT,
        rushing_touchdowns INT,
        receiving_longest_yards INT,
        -- defense
        [total-yards-against] INT,
        [total-yards-against-per-game] VARCHAR(100),
        passing_net_yards_against INT,
        [passing-net-yards-against-per-game] VARCHAR(100),
        rushing_net_yards_against INT,
        [rushing-net-yards-against-per-game] VARCHAR(100),
        third_downs_attempted_against INT,
        third_downs_succeeded_against INT,
        fourth_downs_attempted_against INT,
        fourth_downs_succeeded_against INT,
        [third-down-percentage-against] VARCHAR(100),
        [fourth-down-percentage-against] VARCHAR(100),
        points_against INT,       
        [points-against-per-game] VARCHAR(100),
        defense_solo_tackles INT,
        defense_assisted_tackles INT,
        [defense-tackles-total] INT,
        passing_plays_sacked_against INT,
        passing_plays_intercepted_against INT,
        fumbles_against INT,
        passing_plays_attempted_against INT,
        passing_plays_completed_against INT,
        [passing-plays-percentage-against] VARCHAR(100),
        passing_longest_yards_against INT,
        passing_touchdowns_against INT,            
        rushing_plays_against INT,
        [rushing-net-yards-against-per-play] VARCHAR(100),
        rushing_longest_yards_against INT,
        rushing_touchdowns_against INT,
        receiving_longest_yards_against INT,
        -- special teams
        field_goals_succeeded INT,
        field_goals_attempted INT,
        [field-goals-percentage] VARCHAR(100),
        extra_point_kicks_succeeded INT,
        extra_point_kicks_attempted INT,
        [extra-points-percentage] VARCHAR(100),
        punting_plays INT,
        punting_gross_yards INT,
        punting_longest_yards INT,
        [punting-average] VARCHAR(100),
        punting_inside_twenty INT,
        punting_touchbacks INT,
        punt_return_faircatches_against INT,
        punt_returns_against INT,
        punt_return_yards_against INT,
        [punt-return-against-average] VARCHAR(100),
        kickoff_returns INT,
        kickoff_return_yards INT,
        [kickoff-return-average] VARCHAR(100),
        kickoff_return_longest_yards INT,
        kickoff_return_touchdowns INT,
        punt_returns INT,
        punt_return_yards INT,
        [punt-return-average] VARCHAR(100),
        punt_return_longest_yards INT,
        punt_return_touchdowns INT,
        punt_return_faircatches INT
    )
    DECLARE @leaders TABLE
    (
        ribbon           VARCHAR(100), 
        [rank]           VARCHAR(100),
        value            VARCHAR(100),
        reference_ribbon VARCHAR(100),
        reference_column VARCHAR(100)
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        sub_ribbon VARCHAR(100), 
        player_key VARCHAR(100),
        name       VARCHAR(100)
    )
    -- name
    DECLARE @name VARCHAR(100)
    DECLARE @rgb VARCHAR(100)
        
    SELECT @name = team_last, @rgb = rgb
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @teamKey

                   
    IF (@category = 'defense')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('TOTAL DEFENSE', 'name', '', 'NAME', '', 2),
               ('TOTAL DEFENSE', 'total-yards-against', 'VS OPPONENTS', 'YDS', 'Total Yards', 3),
               ('TOTAL DEFENSE', 'total-yards-against-per-game', 'VS OPPONENTS', 'YDS/G', 'Total Yards Per Game', 4),
               ('TOTAL DEFENSE', 'passing_net_yards_against', 'VS OPPONENTS', 'PASS', 'Total Passing Yards', 5),
               ('TOTAL DEFENSE', 'passing-net-yards-against-per-game', 'VS OPPONENTS', 'P YDS/G', 'Total Passing Yards Per Game', 6),
               ('TOTAL DEFENSE', 'rushing_net_yards_against', 'VS OPPONENTS', 'RUSH', 'Total Rushing Yards', 7),
               ('TOTAL DEFENSE', 'rushing-net-yards-against-per-game', 'VS OPPONENTS', 'R YDS/G', 'Total Rushing Yards Per Game', 8),
               ('TOTAL DEFENSE', 'third-down-percentage-against', 'VS OPPONENTS', '3rd %', '3rd Down Conversions Percentage', 9),
               ('TOTAL DEFENSE', 'fourth-down-percentage-against', 'VS OPPONENTS', '4th %', '4th Down Conversions Percentage', 10),
               ('TOTAL DEFENSE', 'points_against', 'VS OPPONENTS', 'PTS', 'Total Points Scored Against', 11),
               ('TOTAL DEFENSE', 'points-against-per-game', 'VS OPPONENTS', 'PTS/G', 'Total Points Scored Against Per Game', 12),
               ('TOTAL DEFENSE', 'defense_solo_tackles', 'TEAM DEFENSE', 'SOLO TKL', 'Solo Tackles', 13),
               ('TOTAL DEFENSE', 'defense_assisted_tackles', 'TEAM DEFENSE', 'AST TKL', 'Assisted Tackles', 14),
               ('TOTAL DEFENSE', 'defense-tackles-total', 'TEAM DEFENSE', 'TKL', 'Total Tackles', 15),
               ('TOTAL DEFENSE', 'passing_plays_sacked_against', 'TEAM DEFENSE', 'SACK', 'Sacks', 16),
               ('TOTAL DEFENSE', 'passing_plays_intercepted_against', 'TEAM DEFENSE', 'INT', 'Interceptions', 17),
               ('TOTAL DEFENSE', 'fumbles_against', 'TEAM DEFENSE', 'FF', 'Fumbles Forced', 18),

               ('PASSING DEFENSE', 'name', '', 'NAME', '', 2),
               ('PASSING DEFENSE', 'passing_plays_attempted_against', '', 'ATT', 'Passing Attempts', 3),
               ('PASSING DEFENSE', 'passing_plays_completed_against', '', 'COMP', 'Completions', 4),
               ('PASSING DEFENSE', 'passing-plays-percentage-against', '', 'PCT', 'Completions Percentage', 5),
               ('PASSING DEFENSE', 'passing_net_yards_against', '', 'YDS', 'Passing Yards', 6),
               ('PASSING DEFENSE', 'passing-net-yards-against-per-game', '', 'YDS/G', 'Yards Per Game', 7),
               ('PASSING DEFENSE', 'passing_longest_yards_against', '', 'LNG', 'Longest Passing', 8),
               ('PASSING DEFENSE', 'passing_touchdowns_against', '', 'TD', 'Passing Touchdowns', 9),
               ('PASSING DEFENSE', 'passing_plays_intercepted_against', '', 'INT', 'Passes Intercepted', 10),
               ('PASSING DEFENSE', 'passing_plays_sacked_against', '', 'SACK', 'Sacks', 11),

               ('RUSHING DEFENSE', 'name', '', 'NAME', '', 2),
               ('RUSHING DEFENSE', 'rushing_plays_against', '', 'ATT', 'Rushing Attempts', 3),
               ('RUSHING DEFENSE', 'rushing_net_yards_against', '', 'YDS', 'Rushing Yards', 4),
               ('RUSHING DEFENSE', 'rushing-net-yards-against-per-play', '', 'YDS/A', 'Rushing Yards Per Attempts', 5),
               ('RUSHING DEFENSE', 'rushing_longest_yards_against', '', 'LNG', 'Longest Rush', 6),
               ('RUSHING DEFENSE', 'rushing_touchdowns_against', '', 'TD', 'Rushing Touchdowns', 7),
               ('RUSHING DEFENSE', 'rushing-net-yards-against-per-game', '', 'YDS/G', 'Rushing Yards Per Game', 8),

               ('RECEIVING DEFENSE', 'name', '', 'NAME', '', 2),
               ('RECEIVING DEFENSE', 'receiving-receptions-against', '', 'REC', 'Receptions', 3),
               ('RECEIVING DEFENSE', 'receiving-yards-against', '', 'YDS', 'Receptions Yards', 4),
               ('RECEIVING DEFENSE', 'receiving-yards-per-reception', '', 'YDS/REC', 'Average Yards Per Reception', 5),
               ('RECEIVING DEFENSE', 'receiving_longest_yards_against', '', 'LNG', 'Longest Reception', 6),
               ('RECEIVING DEFENSE', 'receiving-touchdowns-against', '', 'TD', 'Reception Touchdowns', 7),
               ('RECEIVING DEFENSE', 'receiving-yards-against-per-game', '', 'YDS/G', 'Reception Yards Per Game', 8)

        IF (@leagueName = 'ncaaf')
        BEGIN
            DELETE @tables
             WHERE [column] IN ('passing_longest_yards_against', 'rushing_longest_yards_against', 'receiving_longest_yards_against')
        END

        INSERT INTO @football (category, games_played,
               [total-yards-against], [total-yards-against-per-game], passing_net_yards_against, rushing_net_yards_against,
               third_downs_attempted_against, third_downs_succeeded_against, fourth_downs_attempted_against, fourth_downs_succeeded_against,
               points_against, [points-against-per-game], defense_solo_tackles, defense_assisted_tackles,
               passing_plays_sacked_against, passing_plays_intercepted_against, fumbles_against,
               passing_plays_attempted_against, passing_plays_completed_against, passing_longest_yards_against, passing_touchdowns_against,
               rushing_plays_against, rushing_longest_yards_against, rushing_touchdowns_against,
               receiving_longest_yards_against)
        SELECT p.category, games_played,
               [total-yards-against], [total-yards-against-per-game], passing_net_yards_against, rushing_net_yards_against,
               ISNULL(third_downs_attempted_against, 0), ISNULL(third_downs_succeeded_against, 0), ISNULL(fourth_downs_attempted_against, 0), ISNULL(fourth_downs_succeeded_against, 0),
               points_against, [points-against-per-game], defense_solo_tackles, defense_assisted_tackles,
               passing_plays_sacked_against, passing_plays_intercepted_against, fumbles_against,
               passing_plays_attempted_against, passing_plays_completed_against, passing_longest_yards_against, passing_touchdowns_against,
               rushing_plays_against, rushing_longest_yards_against, rushing_touchdowns_against,
               receiving_longest_yards_against
          FROM (SELECT category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played,
                                                [total-yards-against], [total-yards-against-per-game], passing_net_yards_against, rushing_net_yards_against,
                                                third_downs_attempted_against, third_downs_succeeded_against, fourth_downs_attempted_against, fourth_downs_succeeded_against,
                                                points_against, [points-against-per-game], defense_solo_tackles, defense_assisted_tackles,
                                                passing_plays_sacked_against, passing_plays_intercepted_against, fumbles_against,
                                                passing_plays_attempted_against, passing_plays_completed_against, passing_longest_yards_against, passing_touchdowns_against,
                                                rushing_plays_against, rushing_longest_yards_against, rushing_touchdowns_against,
                                                receiving_longest_yards_against)) AS p

        -- calculations
        UPDATE @football
           SET [total-yards-against] = passing_net_yards_against + rushing_net_yards_against

        UPDATE @football
           SET [total-yards-against-per-game] = CAST((CAST([total-yards-against] AS FLOAT) / games_played) AS DECIMAL(6, 2)),
               [passing-net-yards-against-per-game] = CAST((CAST(passing_net_yards_against AS FLOAT) / games_played) AS DECIMAL(6, 2)),
               [rushing-net-yards-against-per-game] = CAST((CAST(rushing_net_yards_against AS FLOAT) / games_played) AS DECIMAL(6, 2)),
               [defense-tackles-total] = defense_solo_tackles + defense_assisted_tackles,
               [passing-plays-percentage-against] = CAST((100 * CAST(passing_plays_completed_against AS FLOAT) / passing_plays_attempted_against) AS DECIMAL(4, 1)),
               [rushing-net-yards-against-per-play] = CAST((CAST(rushing_net_yards_against AS FLOAT) / rushing_plays_against) AS DECIMAL(6, 2)),
               [passing-net-yards-per-attempted] = CAST((CAST(passing_net_yards_against AS FLOAT) / passing_plays_attempted_against) AS DECIMAL(6, 2))

        UPDATE @football
           SET [third-down-percentage-against] = CAST((100 * CAST(third_downs_succeeded_against AS FLOAT) / third_downs_attempted_against) AS DECIMAL(4, 1))
         WHERE third_downs_attempted_against > 0

        UPDATE @football
           SET [fourth-down-percentage-against] =  CAST((100 * CAST(fourth_downs_succeeded_against AS FLOAT) / fourth_downs_attempted_against) AS DECIMAL(4, 1))
         WHERE fourth_downs_attempted_against > 0

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'POINTS ALLOWED', CAST(points_against AS VARCHAR) + ' PTS', 'TOTAL DEFENSE', 'points_against'
          FROM @football
         ORDER BY points_against ASC
        
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'points_against')
         WHERE ribbon = 'POINTS ALLOWED'

        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SACKS', CAST(passing_plays_sacked_against AS VARCHAR) + ' SACKS', 'TOTAL DEFENSE', 'passing_plays_sacked_against'
          FROM @football
         ORDER BY passing_plays_sacked_against DESC
        
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'passing_plays_sacked_against')
         WHERE ribbon = 'SACKS'

        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'INTERCEPTIONS', CAST(passing_plays_intercepted_against AS VARCHAR) + ' INT', 'PASSING DEFENSE', 'passing_plays_intercepted_against'
          FROM @football
         ORDER BY passing_plays_intercepted_against DESC

        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'passing_plays_intercepted_against')
         WHERE ribbon = 'INTERCEPTIONS'
/*
        -- players        
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'SACKS' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'sacks-total' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'INTERCEPTIONS' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'interceptions-total' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC
*/

        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('TOTAL DEFENSE', 'total'), ('PASSING DEFENSE', 'passing'), ('RUSHING DEFENSE', 'rushing'), ('RECEIVING DEFENSE', 'receiving')

        SELECT
        (
            SELECT 'DEFENSIVE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 2) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 2) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 2) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END AS [rank], value, reference_ribbon, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'TOTAL DEFENSE'
             ORDER BY [order] ASC
               FOR XML RAW('total_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   [total-yards-against], [total-yards-against-per-game], passing_net_yards_against,
                   [passing-net-yards-against-per-game], rushing_net_yards_against, [rushing-net-yards-against-per-game],
                   [third-down-percentage-against], [fourth-down-percentage-against],
                   points_against, [points-against-per-game], defense_solo_tackles, defense_assisted_tackles,
                   [defense-tackles-total], passing_plays_sacked_against, passing_plays_intercepted_against, fumbles_against
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('total'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'PASSING DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('passing_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   passing_plays_attempted_against, passing_plays_completed_against, [passing-plays-percentage-against],
                   passing_net_yards_against, passing_longest_yards_against, passing_touchdowns_against, passing_plays_intercepted_against,
                   passing_plays_sacked_against, [passing-net-yards-against-per-game]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('passing'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RUSHING DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('rushing_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   rushing_plays_against, rushing_net_yards_against, [rushing-net-yards-against-per-play], rushing_longest_yards_against,
                   [rushing-net-yards-against-per-game], rushing_touchdowns_against
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('rushing'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RECEIVING DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('receiving_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   passing_plays_completed_against AS [receiving-receptions-against], passing_net_yards_against AS [receiving-yards-against],
                   [passing-net-yards-per-attempted] AS [receiving-yards-per-reception], receiving_longest_yards_against,
                   passing_touchdowns_against AS [receiving-touchdowns-against], [passing-net-yards-against-per-game] AS [receiving-yards-against-per-game]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('receiving'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
    ELSE IF (@category = 'special-teams')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('KICKING', 'name', '', 'NAME', '', 2),
               ('KICKING', 'field_goals_succeeded', 'FIELD GOALS', 'FGM', 'Field Goals Made', 3),
               ('KICKING', 'field_goals_attempted', 'FIELD GOALS', 'FGA', 'Field Goals Attempted', 4),
               ('KICKING', 'field-goals-percentage', 'FIELD GOALS', 'PCT', 'Field Goals Percentage', 5),
               ('KICKING', 'extra_point_kicks_succeeded', 'EXTRA POINTS', 'XPM', 'Extra Points Made', 6),
               ('KICKING', 'extra_point_kicks_attempted', 'EXTRA POINTS', 'XPA', 'Extra Point Attempted', 7),
               ('KICKING', 'extra-points-percentage', 'EXTRA POINTS', 'PCT', 'Extra Points Percentage', 8),

               ('PUNTING', 'name', '', 'NAME', '', 2),
               ('PUNTING', 'punting_plays', '', 'ATT', 'Punt Attemps', 4),
               ('PUNTING', 'punting_gross_yards', '', 'YDS', 'Punt Yards', 4),
               ('PUNTING', 'punting_longest_yards', '', 'LNG', 'Longest Punt', 5),
               ('PUNTING', 'punting-average', '', 'AVG', 'Average Per Yards Punt', 6),
               ('PUNTING', 'punting_inside_twenty', '', 'IN20', 'Punts Inside 20 Yard Line', 7),
               ('PUNTING', 'punting_touchbacks', '', 'TB', 'Touchbacks', 8),
               ('PUNTING', 'punt_return_faircatches_against', '', 'FC', 'Fair Catches', 9),
               ('PUNTING', 'punt_returns_against', '', 'RET', 'Punts Return', 10),
               ('PUNTING', 'punt_return_yards_against', '', 'RETY', 'Punt Return Yards', 11),
               ('PUNTING', 'punt-return-against-average', '', 'AVG', 'Average Yards Per Punt Returned', 12),

               ('RETURNING', 'name', '', 'NAME', '', 2),
               ('RETURNING', 'kickoff_returns', 'KICKOFFS', 'ATT', 'Kickoff Return Attempts', 3),
               ('RETURNING', 'kickoff_return_yards', 'KICKOFFS', 'YDS', 'Kickoff Return Yards', 4),
               ('RETURNING', 'kickoff-return-average', 'KICKOFFS', 'AVG', 'Average Yards Per Kickoff Return', 5),
               ('RETURNING', 'kickoff_return_longest_yards', 'KICKOFFS', 'LNG', 'Longest Kickoff Return', 6),
               ('RETURNING', 'kickoff_return_touchdowns', 'KICKOFFS', 'TD', 'Kickoff Return Touchdowns', 7),
               ('RETURNING', 'punt_returns', 'PUNTS', 'ATT', 'Punt Return Attempts', 8),
               ('RETURNING', 'punt_return_yards', 'PUNTS', 'YDS', 'Punt Return Yards', 9),
               ('RETURNING', 'punt-return-average', 'PUNTS', 'AVG', 'Average Yards Per Punt Return', 10),
               ('RETURNING', 'punt_return_longest_yards', 'PUNTS', 'LNG', 'Longest Punt Return', 11),
               ('RETURNING', 'punt_return_touchdowns', 'PUNTS', 'TD', 'Punts Returned For Touchdowns', 12),
               ('RETURNING', 'punt_return_faircatches', 'PUNTS', 'FC', 'Fair Catches', 13)

        IF (@leagueName = 'ncaaf')
        BEGIN
            DELETE @tables
             WHERE [column] IN ('punting_longest_yards', 'punt_return_longest_yards')
        END

        INSERT INTO @football (category,
               field_goals_succeeded, field_goals_attempted, extra_point_kicks_succeeded, extra_point_kicks_attempted,
               punting_plays, punting_gross_yards, punting_longest_yards, punting_inside_twenty, punting_touchbacks,
               punt_return_faircatches_against, punt_returns_against, punt_return_yards_against,
               kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
               punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches)
        SELECT p.category,
               ISNULL(field_goals_succeeded, 0), ISNULL(field_goals_attempted, 0), ISNULL(extra_point_kicks_succeeded, 0), ISNULL(extra_point_kicks_attempted, 0),
               ISNULL(punting_plays, 0), punting_gross_yards, punting_longest_yards, punting_inside_twenty, ISNULL(punting_touchbacks, 0),
               punt_return_faircatches_against, ISNULL(punt_returns_against, 0), punt_return_yards_against,
               kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, ISNULL(kickoff_return_touchdowns, 0),
               punt_returns, punt_return_yards, punt_return_longest_yards, ISNULL(punt_return_touchdowns, 0), ISNULL(punt_return_faircatches, 0)
          FROM (SELECT category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_succeeded, field_goals_attempted, extra_point_kicks_succeeded, extra_point_kicks_attempted,
                                                punting_plays, punting_gross_yards, punting_longest_yards, punting_inside_twenty, punting_touchbacks,
                                                punt_return_faircatches_against, punt_returns_against, punt_return_yards_against,
                                                kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
                                                punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches)) AS p

        -- calculations
        UPDATE @football
           SET [field-goals-percentage] = ROUND((CONVERT(FLOAT, extra_point_kicks_succeeded) / extra_point_kicks_attempted) * 100, 1),
               [extra-points-percentage] = ROUND((CONVERT(FLOAT, field_goals_succeeded) / field_goals_attempted) * 100, 1),
               [punting-average] = CAST((CAST(punting_gross_yards AS FLOAT) / punting_plays) AS DECIMAL(6, 2)),
               [punt-return-against-average] = CAST((CAST(punt_return_yards_against AS FLOAT) / punt_returns_against) AS DECIMAL(6, 2)),
               [kickoff-return-average] = CAST((CAST(kickoff_return_yards AS FLOAT) / kickoff_returns) AS DECIMAL(6, 2)),
               [punt-return-average] = CAST((CAST(punt_return_yards AS FLOAT) / punt_returns) AS DECIMAL(6, 2))

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'KICKING', [field-goals-percentage] + ' FG%', 'KICKING', 'field-goals-percentage'
          FROM @football
         ORDER BY CAST([field-goals-percentage] AS FLOAT) DESC
        
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'field-goals-percentage')
         WHERE ribbon = 'KICKING'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'PUNTING', [punting-average] + ' AVG YDS', 'PUNTING', 'punting-average'
          FROM @football
         ORDER BY CAST([punting-average] AS FLOAT) DESC
         
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'punting-average')
         WHERE ribbon = 'PUNTING'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'KICK RETURNING',
               REPLACE(CONVERT(VARCHAR, CAST(kickoff_return_yards AS MONEY), 1), '.00', '') + ' YDS',
               'RETURNING', 'kickoff_return_yards'
          FROM @football
         ORDER BY kickoff_return_yards DESC
         
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'kickoff_return_yards')
         WHERE ribbon = 'KICK RETURNING'
       
/*
        -- players
        -- percent is calculated, use attempts instead 
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'KICKING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'field-goals-percentage' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'PUNTING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'punts-average' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'KICK RETURNING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'returns-kickoff-yards' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC
*/
        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('KICKING', 'kicking'), ('PUNTING', 'punting'), ('RETURNING', 'returning')

        SELECT
        (
            SELECT 'SPECIAL TEAMS TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 1) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 1) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 1) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END AS [rank], value, reference_ribbon, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'KICKING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('kicking_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   field_goals_succeeded, field_goals_attempted, [field-goals-percentage],
                   extra_point_kicks_succeeded, extra_point_kicks_attempted, [extra-points-percentage]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('kicking'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'PUNTING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('punting_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   punting_plays, punting_gross_yards, punting_longest_yards, [punting-average], punting_inside_twenty, punting_touchbacks,
                   punt_return_faircatches_against, punt_returns_against, punt_return_yards_against, [punt-return-against-average]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('punting'), TYPE                      
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RETURNING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('returning_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name, 
                   kickoff_returns, kickoff_return_yards, [kickoff-return-average],
                   kickoff_return_longest_yards, kickoff_return_touchdowns, punt_returns, punt_return_yards,
                   [punt-return-average], punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches
              FROM @football
             WHERE kickoff_returns + punt_returns > 0
             ORDER BY kickoff_return_yards ASC
               FOR XML RAW('returning'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE       
    END
    ELSE
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('TOTAL OFFENSE', 'name', '', 'NAME', '', 2),
               ('TOTAL OFFENSE', 'total-yards', '', 'YDS', 'Total Yards', 3),
               ('TOTAL OFFENSE', 'total-yards-per-game', '', 'YDS/G', 'Total Yards Per Game', 4),
               ('TOTAL OFFENSE', 'passing_net_yards', '', 'YDS', 'Passing Yards', 5),
               ('TOTAL OFFENSE', 'passing-net-yards-per-game', '', 'P YDS/G', 'Passing Yards Per Game', 6),
               ('TOTAL OFFENSE', 'rushing_net_yards', '', 'RUSH', 'Rushing Yards', 7),
               ('TOTAL OFFENSE', 'rushing-net-yards-per-game', '', 'R YDS/G', 'Rushing Yards Per Game', 8),
               ('TOTAL OFFENSE', 'points', '', 'PTS', 'Points Scored', 9),
               ('TOTAL OFFENSE', 'points-per-game', '', 'PTS/G', 'Points Scored Per Game', 10),

               ('PASSING OFFENSE', 'name', '', 'NAME', '', 2),
               ('PASSING OFFENSE', 'passing_plays_attempted', '', 'ATT', 'Passing Attempts', 3),
               ('PASSING OFFENSE', 'passing_plays_completed', '', 'COMP', 'Completions', 4),
               ('PASSING OFFENSE', 'passing-percentage', '', 'PCT', 'Completion Percentage', 5),
               ('PASSING OFFENSE', 'passing_net_yards', '', 'YDS', 'Passing Yards', 6),
               ('PASSING OFFENSE', 'passing-net-yards-per-attempted', '', 'YDS/A', 'Yards Per Pass Attempt', 7),
               ('PASSING OFFENSE', 'passing_longest_yards', '', 'LNG', 'Longest Pass', 8),
               ('PASSING OFFENSE', 'passing_touchdowns', '', 'TD', 'Passing Touchdowns', 9),
               ('PASSING OFFENSE', 'passing_plays_intercepted', '', 'INT', 'Interceptions Thrown', 10),
               ('PASSING OFFENSE', 'passer_rating', '', 'RAT', 'Passer Rating', 11),
               ('PASSING OFFENSE', 'passing-net-yards-per-game', '', 'YDS/G', 'Pass Yards Per Game', 12),

               ('RUSHING OFFENSE', 'name', '', 'NAME', '', 2),
               ('RUSHING OFFENSE', 'rushing_plays', '', 'ATT', 'Rushing Attempts', 3),
               ('RUSHING OFFENSE', 'rushing_net_yards', '', 'YDS', 'Rushing Yards', 4),
               ('RUSHING OFFENSE', 'rushing-net-yards-per-play', '', 'YDS/A', 'Yards Per Rush Attempt', 5),
               ('RUSHING OFFENSE', 'rushing_longest_yards', '', 'LNG', 'Longest Rush', 6),
               ('RUSHING OFFENSE', 'rushing_touchdowns', '', 'TD', 'Rushing Touchdowns', 7),
               ('RUSHING OFFENSE', 'rushing-net-yards-per-game', '', 'YDS/G', 'Rushing Yards Per Game', 8),

               ('RECEIVING OFFENSE', 'name', '', 'NAME', '', 2),
               ('RECEIVING OFFENSE', 'receiving-receptions', '', 'REC', 'Receptions', 3),
               ('RECEIVING OFFENSE', 'receiving-yards', '', 'YDS', 'Receiving Yards', 4),
               ('RECEIVING OFFENSE', 'receiving-yards-per-reception', '', 'YDS/REC', 'Average Yards Per Reception', 5),
               ('RECEIVING OFFENSE', 'receiving_longest_yards', '', 'LNG', 'Longest Reception', 6),
               ('RECEIVING OFFENSE', 'receiving-touchdowns', '', 'TD', 'Receiving Touchdowns', 7),
               ('RECEIVING OFFENSE', 'receiving-yards-per-game', '', 'YDS/G', 'Receiving Yards Per Game', 8)

        IF (@leagueName = 'ncaaf')
        BEGIN
            DELETE @tables
             WHERE [column] IN ('passing_longest_yards', 'rushing_longest_yards', 'receiving_longest_yards')
        END

        INSERT INTO @football (category, games_played,
               passing_net_yards, rushing_net_yards, points, [points-per-game],
               passing_plays_attempted, passing_plays_completed, passing_longest_yards, passing_touchdowns, passing_plays_intercepted, passer_rating,
               rushing_plays, rushing_longest_yards, rushing_touchdowns,
               receiving_longest_yards)
        SELECT p.category, games_played,
               passing_net_yards, rushing_net_yards, points, [points-per-game],
               passing_plays_attempted, passing_plays_completed, passing_longest_yards, ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0), passer_rating,
               rushing_plays, rushing_longest_yards, ISNULL(rushing_touchdowns, 0),
               receiving_longest_yards
          FROM (SELECT category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, passing_net_yards, rushing_net_yards, points, [points-per-game],
                                                passing_plays_attempted, passing_plays_completed, passing_longest_yards, passing_touchdowns, passing_plays_intercepted, passer_rating,
                                                rushing_plays, rushing_longest_yards, rushing_touchdowns,
                                                receiving_longest_yards)) AS p

        -- calculations
        UPDATE @football
           SET [total-yards] = passing_net_yards + rushing_net_yards

        UPDATE @football
           SET passer_rating = CAST(passer_rating AS DECIMAL(4, 1))
         WHERE passer_rating IS NOT NULL

        UPDATE @football
           SET [total-yards-per-game] = CAST((CAST([total-yards] AS FLOAT) / games_played) AS DECIMAL(6, 2)),
               [passing-net-yards-per-attempted] = CAST((CAST(passing_net_yards AS FLOAT) / passing_plays_attempted) AS DECIMAL(6, 2)),
               [rushing-net-yards-per-play] = CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(6, 2)),
               [passing-percentage] = CAST((100 * CAST(passing_plays_completed AS FLOAT) / passing_plays_attempted) AS DECIMAL(4, 1)),
               [passing-net-yards-per-game] = CAST((CAST(passing_net_yards AS FLOAT) / games_played) AS DECIMAL(6, 2)),
               [rushing-net-yards-per-game] = CAST((CAST(rushing_net_yards AS FLOAT) / games_played) AS DECIMAL(6, 2))
         
        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'PASSING', passing_net_yards, 'PASSING OFFENSE', 'passing_net_yards'
          FROM @football
         ORDER BY passing_net_yards DESC
         
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'passing_net_yards')
         WHERE ribbon = 'PASSING'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RUSHING', rushing_net_yards, 'RUSHING OFFENSE', 'rushing_net_yards'
          FROM @football
         ORDER BY rushing_net_yards DESC
         
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'rushing_net_yards')
         WHERE ribbon = 'RUSHING'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RECEIVING', passing_net_yards, 'RECEIVING OFFENSE', 'receiving-yards'
          FROM @football
         ORDER BY passing_net_yards DESC
         
        UPDATE @leaders
           SET [rank] = (SELECT value FROM @stats WHERE category = 'rank' AND [column] = 'receiving-yards')
         WHERE ribbon = 'RECEIVING'
/*       
        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'PASSING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'passes-yards-gross' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'RUSHING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'rushes-yards' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'RECEIVING' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'receptions-yards' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC
*/
        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('TOTAL OFFENSE', 'total'), ('PASSING OFFENSE', 'passing'), ('RUSHING OFFENSE', 'rushing'), ('RECEIVING OFFENSE', 'receiving')

        SELECT
        (
            SELECT 'OFFENSIVE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 1) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 1) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 1) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END AS [rank],
                   REPLACE(CONVERT(VARCHAR, CAST(value AS MONEY), 1), '.00', '') + ' YDS' AS value,
                   reference_ribbon, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'TOTAL OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('total_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name,
                   [total-yards], [total-yards-per-game], passing_net_yards,
                   [passing-net-yards-per-game], rushing_net_yards, [rushing-net-yards-per-game], points,
                   [points-per-game]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('total'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('passing_plays_intercepted') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'PASSING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('passing_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name,
                   passing_plays_attempted, passing_plays_completed, [passing-percentage], passing_net_yards,
                   [passing-net-yards-per-attempted], passing_longest_yards, passing_touchdowns, passing_plays_intercepted,
                   passer_rating, [passing-net-yards-per-game]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('passing'), TYPE                      
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RUSHING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('rushing_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name,
                   rushing_plays, rushing_net_yards, [rushing-net-yards-per-play], rushing_longest_yards,
                   rushing_touchdowns, [rushing-net-yards-per-game]
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('rushing'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RECEIVING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('receiving_column'), TYPE
        ),
        (
            SELECT CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END AS name,
                   passing_plays_completed AS 'receiving-receptions', passing_net_yards AS 'receiving-yards',
                   [passing-net-yards-per-attempted] AS 'receiving-yards-per-reception', receiving_longest_yards,
                   passing_touchdowns AS 'receiving-touchdowns', [passing-net-yards-per-game] AS 'receiving-yards-per-game'
              FROM @football
             ORDER BY category ASC
               FOR XML RAW('receiving'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE       
    END
END

GO
