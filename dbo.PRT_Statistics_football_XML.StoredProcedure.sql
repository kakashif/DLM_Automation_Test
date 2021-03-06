USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PRT_Statistics_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PRT_Statistics_football_XML]
    @teamId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 08/22/2015
-- Description:	get team statistics for print for football
-- Update: 09/12/2015 - John Lin - passing_gross_yards_against - passing_net_yards_against = passing_sacked_yards_against
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')
    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @team_first VARCHAR(100)
    DECLARE @team_last VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)

    SELECT @season_key = team_season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'nfl' AND page = 'statistics'

    SELECT TOP 1 @team_key = team_key, @team_first = team_first, @team_last = team_last, @team_abbr = team_abbreviation
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_key = '/sport/football/team:' + CAST(@teamId AS VARCHAR)
     ORDER BY season_key DESC

    -- statistics
    DECLARE @stats TABLE
    (
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (player_key, [column], value)
    SELECT player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type AND team_key = @team_key AND category = 'feed'

    DECLARE @teams TABLE
    (
        alignment VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        abbr VARCHAR(100)
    )
    INSERT INTO @teams (alignment, [first], [last], abbr)
    VALUES ('self', @team_first, @team_last, @team_abbr), ('opponent', NULL, NULL, NULL)

    -- passing
    DECLARE @passing TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        passing_plays_attempted INT,
        passing_plays_completed INT,
        passing_net_yards INT,
        passing_gross_yards INT,
        passing_touchdowns INT,
        passing_plays_intercepted INT,
        passing_longest_yards INT,
        passing_plays_sacked INT,
        passing_sacked_yards INT,
        passer_rating VARCHAR(100)
    )
	INSERT INTO @passing (alignment, player_key, passing_plays_attempted, passing_plays_completed, passing_net_yards,
	                      passing_touchdowns, passing_plays_intercepted, passing_longest_yards, passing_plays_sacked, passing_sacked_yards, passer_rating)
    SELECT 'self', 'team', ISNULL(passing_plays_attempted, 0), ISNULL(passing_plays_completed, 0), ISNULL(passing_net_yards, 0),
	       ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0), passing_longest_yards, ISNULL(passing_plays_sacked, 0),
	       ISNULL(passing_sacked_yards, 0), passer_rating
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_attempted, passing_plays_completed, passing_net_yards, passing_yards,
	                                        passing_touchdowns, passing_plays_intercepted, passing_longest_yards, passing_plays_sacked,
	                                        passing_sacked_yards, passer_rating)) AS p

	INSERT INTO @passing (alignment, player_key, passing_plays_attempted, passing_plays_completed, passing_net_yards,
	                      passing_touchdowns, passing_plays_intercepted, passing_longest_yards, passing_plays_sacked, passing_sacked_yards, passer_rating)
    SELECT 'self', p.player_key, ISNULL(passing_plays_attempted, 0), ISNULL(passing_plays_completed, 0), ISNULL(passing_yards, 0),
	       ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0), passing_longest_yards, ISNULL(passing_plays_sacked, 0),
	       ISNULL(passing_sacked_yards, 0), passer_rating
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_attempted, passing_plays_completed, passing_net_yards, passing_yards,
	                                        passing_touchdowns, passing_plays_intercepted, passing_longest_yards, passing_plays_sacked,
	                                        passing_sacked_yards, passer_rating)) AS p

	INSERT INTO @passing (alignment, player_key, passing_plays_attempted, passing_plays_completed, passing_net_yards,
	                      passing_touchdowns, passing_plays_intercepted, passing_longest_yards, passing_plays_sacked, passing_sacked_yards, passer_rating)
    SELECT 'opponent', 'team', ISNULL(passing_plays_attempted_against, 0), ISNULL(passing_plays_completed_against, 0), ISNULL(passing_net_yards_against, 0),
	       ISNULL(passing_touchdowns_against, 0), ISNULL(passing_plays_intercepted_against, 0), passing_longest_yards_against,
	       ISNULL(passing_plays_sacked_against, 0), CAST(ISNULL(passing_gross_yards_against, 0) AS INT) - CAST(ISNULL(passing_net_yards_against, 0) AS INT),
	       passer_rating_against
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_attempted_against, passing_plays_completed_against, passing_net_yards_against, passing_gross_yards_against,
	                                        passing_touchdowns_against, passing_plays_intercepted_against, passing_longest_yards_against,
	                                        passing_plays_sacked_against, passing_sacked_yards_against, passer_rating_against)) AS p

    DELETE @passing
     WHERE passing_plays_attempted = 0 AND player_key <> 'team'

    UPDATE @passing
       SET passer_rating = ROUND(CAST(passer_rating AS FLOAT), 1)

    UPDATE p
       SET p.[first] = sp.first_name, p.[last] = sp.last_name
      FROM @passing p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key
    
    -- rushing
    DECLARE @rushing TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		rushing_plays INT,
        rushing_net_yards INT,
        rushing_longest_yards INT,
        rushing_touchdowns INT
    )
	INSERT INTO @rushing (alignment, player_key, rushing_plays, rushing_net_yards, rushing_longest_yards, rushing_touchdowns)
    SELECT 'self', 'team', ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), rushing_longest_yards, ISNULL(rushing_touchdowns, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (rushing_plays, rushing_net_yards, rushing_longest_yards, rushing_touchdowns)) AS p

	INSERT INTO @rushing (alignment, player_key, rushing_plays, rushing_net_yards, rushing_longest_yards, rushing_touchdowns)
    SELECT 'self', p.player_key, ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_longest_yards, 0), ISNULL(rushing_touchdowns, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (rushing_plays, rushing_net_yards, rushing_longest_yards, rushing_touchdowns)) AS p

	INSERT INTO @rushing (alignment, player_key, rushing_plays, rushing_net_yards, rushing_longest_yards, rushing_touchdowns)
    SELECT 'opponent', 'team', ISNULL(rushing_plays_against, 0), ISNULL(rushing_net_yards_against, 0), rushing_longest_yards_against, ISNULL(rushing_touchdowns_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (rushing_plays_against, rushing_net_yards_against, rushing_longest_yards_against, rushing_touchdowns_against)) AS p

    DELETE @rushing
     WHERE rushing_plays = 0 AND player_key <> 'team'
     
    UPDATE r
       SET r.[first] = sp.first_name, r.[last] = sp.last_name
      FROM @rushing r
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = r.player_key

    -- receiving
    DECLARE @receiving TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
   		receiving_receptions INT,
		receiving_yards INT,
        receiving_longest_yards INT,
		receiving_touchdowns INT
    )
	INSERT INTO @receiving (alignment, player_key, receiving_receptions, receiving_yards, receiving_longest_yards, receiving_touchdowns)
    SELECT 'self', 'team', ISNULL(passing_plays_completed, 0), ISNULL(passing_gross_yards, 0), receiving_longest_yards, ISNULL(passing_touchdowns, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_completed, passing_gross_yards, receiving_longest_yards, passing_touchdowns)) AS p

	INSERT INTO @receiving (alignment, player_key, receiving_receptions, receiving_yards, receiving_longest_yards, receiving_touchdowns)
    SELECT 'self', p.player_key, ISNULL(receiving_receptions, 0), ISNULL(receiving_yards, 0), ISNULL(receiving_longest_yards, 0), ISNULL(receiving_touchdowns, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (receiving_receptions, receiving_yards, receiving_longest_yards, receiving_touchdowns)) AS p

	INSERT INTO @receiving (alignment, player_key, receiving_receptions, receiving_yards, receiving_longest_yards, receiving_touchdowns)
    SELECT 'opponent', 'team', ISNULL(passing_plays_completed_against, 0), ISNULL(passing_gross_yards_against, 0), receiving_longest_yards_against,
           ISNULL(passing_touchdowns_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_completed_against, passing_gross_yards_against, receiving_longest_yards_against, passing_touchdowns_against)) AS p

    DELETE @receiving
     WHERE receiving_receptions = 0 AND player_key <> 'team'

    UPDATE r
       SET r.[first] = sp.first_name, r.[last] = sp.last_name
      FROM @receiving r
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = r.player_key

    -- interceptions
    DECLARE @interceptions TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		interception_returns INT,
		interception_return_yards INT,
		interception_touchdowns INT
    )
	INSERT INTO @interceptions (alignment, player_key, interception_returns, interception_return_yards, interception_touchdowns)
    SELECT 'self', 'team', ISNULL(interception_returns, 0), ISNULL(interception_return_yards, 0), ISNULL(interception_touchdowns, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (interception_returns, interception_return_yards, interception_touchdowns)) AS p

	INSERT INTO @interceptions (alignment, player_key, interception_returns, interception_return_yards, interception_touchdowns)
    SELECT 'self', p.player_key, ISNULL(defense_interceptions, 0), ISNULL(defense_interception_yards, 0), ISNULL(interceptions_returned_touchdowns, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (defense_interceptions, defense_interception_yards, interceptions_returned_touchdowns)) AS p

	INSERT INTO @interceptions (alignment, player_key, interception_returns, interception_return_yards, interception_touchdowns)
    SELECT 'opponent', 'team', ISNULL(interception_returns_against, 0), interception_return_yards_against, ISNULL(interception_touchdowns_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (interception_returns_against, interception_return_yards_against, interception_touchdowns_against)) AS p

    DELETE @interceptions
     WHERE interception_returns = 0 AND player_key <> 'team'

    UPDATE i
       SET i.[first] = sp.first_name, i.[last] = sp.last_name
      FROM @interceptions i
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = i.player_key

    -- kicking
    DECLARE @kicking TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        field_goals_attempted INT,
        field_goals_succeeded INT,
        extra_point_kicks_attempted INT,
        extra_point_kicks_succeeded INT
    )
	INSERT INTO @kicking (alignment, player_key, field_goals_attempted, field_goals_succeeded, extra_point_kicks_attempted, extra_point_kicks_succeeded)
    SELECT 'self', 'team', ISNULL(field_goals_attempted, 0), ISNULL(field_goals_succeeded, 0),
           ISNULL(extra_point_kicks_attempted, 0), ISNULL(extra_point_kicks_succeeded, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_attempted, field_goals_succeeded, extra_point_kicks_attempted, extra_point_kicks_succeeded)) AS p

	INSERT INTO @kicking (alignment, player_key, field_goals_attempted, field_goals_succeeded, extra_point_kicks_attempted, extra_point_kicks_succeeded)
    SELECT 'self', p.player_key, ISNULL(field_goals_attempted, 0), ISNULL(field_goals_succeeded, 0),
           ISNULL(extra_point_kicks_attempted, 0), ISNULL(extra_point_kicks_succeeded, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_attempted, field_goals_succeeded, extra_point_kicks_attempted, extra_point_kicks_succeeded)) AS p

	INSERT INTO @kicking (alignment, player_key, field_goals_attempted, field_goals_succeeded, extra_point_kicks_attempted, extra_point_kicks_succeeded)
    SELECT 'opponent', 'team', ISNULL(field_goals_attempted_against, 0), ISNULL(field_goals_succeeded_against, 0),
           ISNULL(extra_point_kicks_attempted_against, 0), ISNULL(extra_point_kicks_succeeded_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_attempted_against, field_goals_succeeded_against, extra_point_kicks_attempted_against,
                                            extra_point_kicks_succeeded_against)) AS p

    DELETE @kicking
     WHERE field_goals_attempted + extra_point_kicks_attempted = 0 AND player_key <> 'team'

    UPDATE k
       SET k.[first] = sp.first_name, k.[last] = sp.last_name
      FROM @kicking k
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = k.player_key

    -- scoring
    DECLARE @scoring TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        total_touchdowns INT,
        rushing_touchdowns INT,
        receiving_touchdowns INT,
        punt_return_touchdowns INT,
        points INT       
    )
	INSERT INTO @scoring (alignment, player_key, total_touchdowns, rushing_touchdowns, receiving_touchdowns, punt_return_touchdowns, points)
    SELECT 'self', 'team', ISNULL(total_touchdowns, 0), ISNULL(rushing_touchdowns, 0), ISNULL(passing_touchdown, 0),
           ISNULL(punt_return_touchdowns, 0), ISNULL(points, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (total_touchdowns, rushing_touchdowns, passing_touchdown, punt_return_touchdowns, points)) AS p

	INSERT INTO @scoring (alignment, player_key, total_touchdowns, rushing_touchdowns, receiving_touchdowns, punt_return_touchdowns, points)
    SELECT 'self', p.player_key, ISNULL(total_touchdowns, 0), ISNULL(rushing_touchdowns, 0), ISNULL(receiving_touchdowns, 0),
           ISNULL(punt_return_touchdowns, 0), ISNULL(points, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (total_touchdowns, rushing_touchdowns, receiving_touchdowns, punt_return_touchdowns, points)) AS p

	INSERT INTO @scoring (alignment, player_key, total_touchdowns, rushing_touchdowns, receiving_touchdowns, punt_return_touchdowns, points)
    SELECT 'opponent', 'team', ISNULL(total_touchdowns_against, 0), ISNULL(rushing_touchdowns_against, 0), ISNULL(passing_touchdown_against, 0),
           ISNULL(punt_return_touchdowns_against, 0), ISNULL(points_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (total_touchdowns_against, rushing_touchdowns_against, passing_touchdown_against,
                                            punt_return_touchdowns_against, points_against)) AS p

    DELETE @scoring
     WHERE points = 0

    UPDATE s
       SET s.[first] = sp.first_name, s.[last] = sp.last_name
      FROM @scoring s
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = s.player_key

    -- miscellanies
    DECLARE @miscellanies TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        defense_sacks VARCHAR(100),
        fumbles INT,
        fumbles_lost INT
    )
	INSERT INTO @miscellanies (alignment, player_key, defense_sacks, fumbles, fumbles_lost)
    SELECT 'self', 'team', ISNULL(passing_plays_sacked, 0), ISNULL(fumbles, 0), ISNULL(fumbles_lost, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_sacked, fumbles, fumbles_lost)) AS p

	INSERT INTO @miscellanies (alignment, player_key, defense_sacks, fumbles, fumbles_lost)
    SELECT 'self', p.player_key, ISNULL(defense_sacks, 0), ISNULL(fumbles, 0), ISNULL(fumbles_lost, 0)
      FROM (SELECT player_key, [column], value FROM @stats WHERE player_key <> 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (defense_sacks, fumbles, fumbles_lost)) AS p

	INSERT INTO @miscellanies (alignment, player_key, defense_sacks, fumbles, fumbles_lost)
    SELECT 'opponent', 'team', ISNULL(passing_plays_sacked_against, 0), ISNULL(fumbles_against, 0), ISNULL(fumbles_lost_against, 0)
      FROM (SELECT [column], value FROM @stats WHERE player_key = 'team') AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_sacked_against, fumbles_against, fumbles_lost_against)) AS p

    DELETE @miscellanies
     WHERE CAST(defense_sacks AS FLOAT) + fumbles + fumbles_lost = 0

    UPDATE @miscellanies
       SET defense_sacks = NULL
     WHERE player_key <> 'team' AND CAST(defense_sacks AS FLOAT) = 0

    UPDATE @miscellanies
       SET fumbles = NULL, fumbles_lost = NULL
     WHERE player_key <> 'team' AND (fumbles + fumbles_lost) = 0

    UPDATE m
       SET m.[first] = sp.first_name, m.[last] = sp.last_name
      FROM @miscellanies m
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = m.player_key

    -- event details
    DECLARE @details TABLE
    (
        alignment VARCHAR(100),
        player_key VARCHAR(100),
        -- details
        games_played INT,
        time_of_possession_secs VARCHAR(100),
        passing_net_yards INT,
        rushing_net_yards INT,
        passing_plays_attempted INT,
        rushing_plays INT,
        passing_plays_sacked INT,
        total_first_downs INT,
        rushing_first_downs INT,
        passing_first_downs INT,
        penalty_first_downs INT,
        third_downs_attempted INT,
        third_downs_succeeded INT,
        fourth_downs_attempted INT,
        fourth_downs_succeeded INT,
        penalties INT,
        penalty_yards INT
    )
    INSERT INTO @details (alignment, player_key, games_played, time_of_possession_secs,
                          passing_net_yards, rushing_net_yards, passing_plays_attempted, rushing_plays, passing_plays_sacked,
                          total_first_downs, rushing_first_downs, passing_first_downs, penalty_first_downs,
                          third_downs_attempted, third_downs_succeeded, fourth_downs_attempted, fourth_downs_succeeded,
                          penalties, penalty_yards)
    SELECT 'self', p.player_key, games_played, time_of_possession_secs,
           passing_net_yards, rushing_net_yards, passing_plays_attempted, rushing_plays, ISNULL(passing_plays_sacked, 0),
           total_first_downs, rushing_first_downs, passing_first_downs, ISNULL(penalty_first_downs, 0),
           third_downs_attempted, ISNULL(third_downs_succeeded, 0), ISNULL(fourth_downs_attempted, 0), ISNULL(fourth_downs_succeeded, 0),
           ISNULL(penalties, 0), ISNULL(penalty_yards, 0)
      FROM (SELECT player_key, [column], value FROM @stats) AS c
     PIVOT (MAX(c.value) FOR c.[column] IN (games_played, time_of_possession_secs,
                                            passing_net_yards, rushing_net_yards, passing_plays_attempted, rushing_plays, passing_plays_sacked,
                                            total_first_downs, rushing_first_downs, passing_first_downs, penalty_first_downs,
                                            third_downs_attempted, third_downs_succeeded, fourth_downs_attempted, fourth_downs_succeeded,
                                            penalties, penalty_yards)) AS p    

    INSERT INTO @details (alignment, player_key, games_played, time_of_possession_secs,
                          passing_net_yards, rushing_net_yards, passing_plays_attempted, rushing_plays, passing_plays_sacked,
                          total_first_downs, rushing_first_downs, passing_first_downs, penalty_first_downs,
                          third_downs_attempted, third_downs_succeeded, fourth_downs_attempted, fourth_downs_succeeded,
                          penalties, penalty_yards)
    SELECT 'opponent', p.player_key, games_played, time_of_possession_secs_against,
           passing_net_yards_against, rushing_net_yards_against, passing_plays_attempted_against, rushing_plays_against, ISNULL(passing_plays_sacked_against, 0),
           total_first_downs_against, rushing_first_downs_against, passing_first_downs_against, ISNULL(penalty_first_downs_against, 0),
           third_downs_attempted_against, ISNULL(third_downs_succeeded_against, 0), ISNULL(fourth_downs_attempted_against, 0), ISNULL(fourth_downs_succeeded_against, 0),
           ISNULL(penalties_against, 0), ISNULL(penalty_yards_against, 0)
      FROM (SELECT player_key, [column], value FROM @stats) AS c
     PIVOT (MAX(c.value) FOR c.[column] IN (games_played, time_of_possession_secs_against,
                                            passing_net_yards_against, rushing_net_yards_against, passing_plays_attempted_against, rushing_plays_against, passing_plays_sacked_against,
                                            total_first_downs_against, rushing_first_downs_against, passing_first_downs_against, penalty_first_downs_against,
                                            third_downs_attempted_against, third_downs_succeeded_against, fourth_downs_attempted_against, fourth_downs_succeeded_against,
                                            penalties_against, penalty_yards_against)) AS p

    DELETE @details
     WHERE player_key <> 'team'
  


    SELECT 
    (
        SELECT
        (
            SELECT t.alignment AS '@alignment', t.[first] AS '@first', t.[last] AS '@last', t.abbr AS '@abbreviation',
            (
                SELECT d.games_played AS '@games-played', d.time_of_possession_secs AS '@time-of-possession-secs',
                       d.passing_net_yards AS '@passing-net-yards', d.rushing_net_yards AS '@rushing-net-yards',
                       d.passing_plays_attempted AS '@passing-plays-attempted', d.rushing_plays AS '@rushing-plays', d.passing_plays_sacked AS '@passing-plays-sacked',
                       d.total_first_downs AS '@total-first-downs', d.rushing_first_downs AS '@rushing-first-downs',
                       d.passing_first_downs AS '@passing-first-downs', d.penalty_first_downs AS '@penalty-first-downs',
                       d.third_downs_attempted AS '@third-downs-attempted', d.third_downs_succeeded AS '@third-downs-succeeded',
                       d.fourth_downs_attempted AS '@fourth-downs-attempted', d.fourth_downs_succeeded AS '@fourth-downs-succeeded',
                       d.penalties AS '@penalties', d.penalty_yards AS '@penalty-yards'
                  FROM @details d
                 WHERE d.alignment = t.alignment
                   FOR XML PATH('details'), TYPE
            ),
            (
                SELECT p.passing_plays_attempted AS '@passing-plays-attempted', p.passing_plays_completed AS '@passing-plays-completed',
                       p.passing_net_yards AS '@passing-net-yards', p.passing_touchdowns AS '@passing-touchdowns',
                       p.passing_plays_intercepted AS '@passing-plays-intercepted', p.passing_longest_yards AS '@passing-longest-yards',
                       p.passing_plays_sacked AS '@passing-plays-sacked', p.passing_sacked_yards AS '@passing-sacked-yards', p.passer_rating AS '@passer-rating',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.passing_plays_attempted AS '@passing-plays-attempted', pl.passing_plays_completed AS '@passing-plays-completed',
                                      pl.passing_net_yards AS '@passing-net-yards', pl.passing_touchdowns AS '@passing-touchdowns',
                                      pl.passing_plays_intercepted AS '@passing-plays-intercepted', pl.passing_longest_yards AS '@passing-longest-yards',
                                      pl.passing_plays_sacked AS '@passing-plays-sacked', pl.passing_sacked_yards AS '@passing-sacked-yards', pl.passer_rating AS '@passer-rating'
                                 FROM @passing pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY pl.passing_net_yards DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @passing p
                 WHERE p.alignment = t.alignment AND p.player_key = 'team'
                   FOR XML PATH('passing'), TYPE
            ),
            (
                SELECT r.rushing_plays AS '@rushing-plays', r.rushing_net_yards AS '@rushing-net-yards',
                       r.rushing_longest_yards AS '@rushing-longest-yards', r.rushing_touchdowns AS '@rushing-touchdowns',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.rushing_plays AS '@rushing-plays', pl.rushing_net_yards AS '@rushing-net-yards',
                                      pl.rushing_longest_yards AS '@rushing-longest-yards', pl.rushing_touchdowns AS '@rushing-touchdowns'
                                 FROM @rushing pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY pl.rushing_net_yards DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @rushing r
                 WHERE r.alignment = t.alignment AND r.player_key = 'team'
                   FOR XML PATH('rushing'), TYPE
            ),
            (
                SELECT r.receiving_receptions AS '@receiving-receptions', r.receiving_yards AS '@receiving-yards',
                       r.receiving_longest_yards AS '@receiving-longest-yards', r.receiving_touchdowns AS '@receiving-touchdowns',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.receiving_receptions AS '@receiving-receptions', pl.receiving_yards AS '@receiving-yards',
                                      pl.receiving_longest_yards AS '@receiving-longest-yards', pl.receiving_touchdowns AS '@receiving-touchdowns'
                                 FROM @receiving pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY pl.receiving_yards DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @receiving r
                 WHERE r.alignment = t.alignment AND r.player_key = 'team'
                   FOR XML PATH('receiving'), TYPE
            ),
            (
                SELECT i.interception_returns AS '@interception-returns', i.interception_return_yards AS '@interception-return-yards',
                       i.interception_touchdowns AS '@interception-touchdowns',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.interception_returns AS '@interception-returns', pl.interception_return_yards AS '@interception-return-yards',
                                      pl.interception_touchdowns AS '@interception-touchdowns'
                                 FROM @interceptions pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY pl.interception_return_yards DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @interceptions i
                 WHERE i.alignment = t.alignment AND i.player_key = 'team'
                   FOR XML PATH('interceptions'), TYPE
            ),
            (
                SELECT k.field_goals_attempted AS '@field-goals-attempted', k.field_goals_succeeded AS '@field-goals-succeeded',
                       k.extra_point_kicks_attempted AS '@extra-point-kicks-attempted', k.extra_point_kicks_succeeded AS '@extra-point-kicks-succeeded',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.field_goals_attempted AS '@field-goals-attempted', pl.field_goals_succeeded AS '@field-goals-succeeded',
                                      pl.extra_point_kicks_attempted AS '@extra-point-kicks-attempted', pl.extra_point_kicks_succeeded AS '@extra-point-kicks-succeeded'
                                 FROM @kicking pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY (pl.field_goals_succeeded + extra_point_kicks_succeeded) DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @kicking k
                 WHERE k.alignment = t.alignment AND k.player_key = 'team'
                   FOR XML PATH('kicking'), TYPE
            ),
            (
                SELECT s.total_touchdowns AS '@total-touchdowns', s.rushing_touchdowns AS '@rushing-touchdowns', s.receiving_touchdowns AS '@receiving-touchdowns',
                       s.punt_return_touchdowns AS '@punt-return-touchdowns', s.points AS '@points',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.total_touchdowns AS '@total-touchdowns', pl.rushing_touchdowns AS '@rushing-touchdowns',
                                      pl.receiving_touchdowns AS '@receiving-touchdowns', pl.punt_return_touchdowns AS '@punt-return-touchdowns',
                                      pl.points AS '@points'
                                 FROM @scoring pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY pl.points DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @scoring s
                 WHERE s.alignment = t.alignment AND s.player_key = 'team'
                   FOR XML PATH('scoring'), TYPE
            ),
            (
                SELECT s.defense_sacks AS '@defense-sacks', s.fumbles AS '@fumbles', s.fumbles_lost AS '@fumbles-losts',
                       (
                           SELECT
                           (
                               SELECT pl.[first] AS '@first', pl.[last] AS '@last',
                                      pl.defense_sacks AS '@defense-sacks', pl.fumbles AS '@fumbles', pl.fumbles_lost AS '@fumbles-losts'
                                 FROM @miscellanies pl
                                WHERE pl.alignment = t.alignment AND pl.player_key <> 'team'
                                ORDER BY CAST(pl.defense_sacks AS FLOAT) DESC
                                  FOR XML PATH('player'), TYPE
                           )
                           FOR XML PATH('players'), TYPE
                       )
                  FROM @miscellanies s
                 WHERE s.alignment = t.alignment AND s.player_key = 'team'
                   FOR XML PATH('miscellanies'), TYPE
            )
            FROM @teams t
            ORDER BY t.alignment DESC
            FOR XML PATH('team'), TYPE
        )
        FOR XML PATH('teams'), TYPE
    )
	FOR XML PATH('statistics')

    SET NOCOUNT OFF;
END

GO
