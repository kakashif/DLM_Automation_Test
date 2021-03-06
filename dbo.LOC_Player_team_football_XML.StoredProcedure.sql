USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_team_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[LOC_Player_team_football_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @teamSlug VARCHAR(100),
    @playerId INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 04/29/2015
  -- Description: get football player statistics for USCP
  -- Update: 05/15/2015 - John Lin - remove experience for ncaaf
  --         08/28/2015 - John Lin - add team slug
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @sub_season_type VARCHAR(100) = 'pre-season'
    DECLARE @team_key VARCHAR(100)
    DECLARE @player_key VARCHAR(100)
    
    SELECT TOP 1 @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    SELECT TOP 1 @player_key = player_key
      FROM dbo.SMG_Rosters
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @team_key AND player_key LIKE '%' + CAST(@playerId AS VARCHAR)

    IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Statistics
                       WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND team_key = @team_key AND player_key = @player_key)
    BEGIN
        SET @sub_season_type = 'season-regular'
    END

    DECLARE @player TABLE
    (
		player_key     VARCHAR(100),
		id             VARCHAR(100),
		uniform_number VARCHAR(100),
		position       VARCHAR(100),
		height         VARCHAR(100),
		[weight]       INT,
        head_shot      VARCHAR(200),
        [filename]     VARCHAR(100),
		first_name     VARCHAR(100),
		last_name      VARCHAR(100),
		-- extra
		college        VARCHAR(100),
		dob            VARCHAR(100),
		experience     VARCHAR(100),
		class          VARCHAR(100)
    )
    INSERT INTO @player (player_key, uniform_number, position, height, [weight], head_shot, [filename], class)
    SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename], subphase_type
      FROM dbo.SMG_Rosters
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @team_key AND player_key = @player_key AND phase_status <> 'delete'

    UPDATE p
       SET p.first_name = sp.first_name, p.last_name = sp.last_name,
           p.college = sp.college_name, p.experience = sp.duration,
           p.dob = CAST(DATEPART(MONTH, sp.date_of_birth) AS VARCHAR) + '/' +
                   CAST(DATEPART(DAY, sp.date_of_birth) AS VARCHAR) + '/' +
                   CAST(DATEPART(YEAR, sp.date_of_birth) AS VARCHAR)
      FROM @player p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key

    IF (@leagueName = 'ncaaf')
    BEGIN
        UPDATE @player
           SET experience = NULL
    END

    UPDATE @player
       SET uniform_number = ''           
     WHERE uniform_number IS NULL OR uniform_number = 0

    UPDATE @player
       SET head_shot = 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
     WHERE head_shot IS NOT NULL AND [filename] IS NOT NULL

    DECLARE @football TABLE
    (
        scoring INT,
        passing_touchdowns VARCHAR(100),
        rushing_touchdowns VARCHAR(100),
        receiving_touchdowns VARCHAR(100),
        interceptions_returned_touchdowns VARCHAR(100),
        fumbles_recovered_touchdowns VARCHAR(100),
        kickoff_return_touchdowns VARCHAR(100),
        punt_return_touchdowns VARCHAR(100),
        total_touchdowns VARCHAR(100),
        field_goals_succeeded VARCHAR(100),
        extra_point_kicks_succeeded VARCHAR(100),
        [points-scored-for] VARCHAR(100),
        [points-scored-for-per-game] VARCHAR(100),
        passing INT,
        passing_plays_completed VARCHAR(100),
        passing_plays_attempted VARCHAR(100),
        [passes-percentage] VARCHAR(100),
        passer_rating VARCHAR(100),
        passing_yards VARCHAR(100),
        [passes-average-yards-per] VARCHAR(100),
        [passes-yards-gross-per-game] VARCHAR(100),
        passing_longest_yards VARCHAR(100),
        passing_plays_intercepted VARCHAR(100),
        passing_plays_sacked VARCHAR(100),
        rushing INT,
        rushing_plays VARCHAR(100),
        rushing_net_yards VARCHAR(100),
        [rushing-average-yards-per] VARCHAR(100),
        rushing_longest_yards VARCHAR(100),
        [rushes-yards-per-game] VARCHAR(100),
        [fumbles-committed] VARCHAR(100),
        receiving INT,
        [receptions-total] VARCHAR(100),
        [receptions-yards] VARCHAR(100),
        [receptions-average-yards-per] VARCHAR(100),
        [receptions-longest] VARCHAR(100),
        [receptions-yards-per-game] VARCHAR(100),
        defense INT,
        [tackles-solo] VARCHAR(100),
        [tackles-assists] VARCHAR(100),
        [tackles-total] VARCHAR(100),
        [sacks-total] VARCHAR(100),
        [interceptions-total] VARCHAR(100),
        [interceptions-yards] VARCHAR(100),
        [interceptions-longest] VARCHAR(100),
        [fumbles-forced] VARCHAR(100),
        [fumbles-opposing-recovered] VARCHAR(100),
        kicking INT,
        [field-goal-attempts] VARCHAR(100),
        [field-goals-percentage] VARCHAR(100),
        [extra-points-attempts] VARCHAR(100),
        [extra-points-percentage] VARCHAR(100),
        punting INT,
        [punts-total] VARCHAR(100),
        [punts-yards-gross] VARCHAR(100),
        [punts-longest] VARCHAR(100),
        [punts-average] VARCHAR(100),
        [punts-inside-20] VARCHAR(100),
        [touchbacks-total] VARCHAR(100),
        returning INT,
        [returns-kickoff-total] VARCHAR(100),
        [returns-kickoff-yards] VARCHAR(100),
        [returns-kickoff-average] VARCHAR(100),
        [returns-kickoff-longest] VARCHAR(100),
        [returns-punt-total] VARCHAR(100),
        [returns-punt-yards] VARCHAR(100),
        [returns-punt-average] VARCHAR(100),
        [returns-punt-longest] VARCHAR(100),
        [fair-catches] VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )

    INSERT INTO @stats ([column], value)
    SELECT [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND team_key = @team_key AND player_key = @player_key

    INSERT INTO @football (passing_touchdowns, rushing_touchdowns, receiving_touchdowns,
                           interceptions_returned_touchdowns, fumbles_recovered_touchdowns,
                           kickoff_return_touchdowns, punt_return_touchdowns, total_touchdowns,
                           field_goals_succeeded, extra_point_kicks_succeeded, [points-scored-for],
                           [points-scored-for-per-game], passing_plays_completed, passing_plays_attempted,
                           [passes-percentage], passer_rating, passing_yards,
                           [passes-average-yards-per], [passes-yards-gross-per-game], passing_longest_yards,
                           passing_plays_intercepted, passing_plays_sacked,
                           rushing_plays, rushing_net_yards, [rushing-average-yards-per],
                           rushing_longest_yards, [rushes-yards-per-game], [fumbles-committed],
                           [receptions-total], [receptions-yards], [receptions-average-yards-per],
                           [receptions-longest], [receptions-yards-per-game],
                           [tackles-solo], [tackles-assists], [tackles-total], [sacks-total],
                           [interceptions-total], [interceptions-yards], [interceptions-longest],
                           [fumbles-forced], [fumbles-opposing-recovered],
                           [field-goal-attempts], [field-goals-percentage], [extra-points-attempts],
                           [extra-points-percentage],
                           [punts-total], [punts-yards-gross], [punts-longest], [punts-average],
                           [punts-inside-20], [touchbacks-total],
                           [returns-kickoff-total], [returns-kickoff-yards], [returns-kickoff-average],
                           [returns-kickoff-longest], [returns-punt-total], [returns-punt-yards],
                           [returns-punt-average], [returns-punt-longest], [fair-catches])
    SELECT passing_touchdowns, rushing_touchdowns, receiving_touchdowns,
           interceptions_returned_touchdowns, fumbles_recovered_touchdowns,
           kickoff_return_touchdowns, punt_return_touchdowns, total_touchdowns,
           field_goals_succeeded, extra_point_kicks_succeeded, [points-scored-for],
           [points-scored-for-per-game], passing_plays_completed, passing_plays_attempted,
           [passes-percentage], passer_rating, passing_yards,
           [passes-average-yards-per], [passes-yards-gross-per-game], passing_longest_yards,
           passing_plays_intercepted, passing_plays_sacked,
           rushing_plays, rushing_net_yards, [rushing-average-yards-per],
           rushing_longest_yards, [rushes-yards-per-game], [fumbles-committed],
           [receptions-total], [receptions-yards], [receptions-average-yards-per],
           [receptions-longest], [receptions-yards-per-game],
           [tackles-solo], [tackles-assists], [tackles-total], [sacks-total],
           [interceptions-total], [interceptions-yards], [interceptions-longest],
           [fumbles-forced], [fumbles-opposing-recovered],
           [field-goal-attempts], [field-goals-percentage], [extra-points-attempts],
           [extra-points-percentage],
           [punts-total], [punts-yards-gross], [punts-longest], [punts-average],
           [punts-inside-20], [touchbacks-total],
           [returns-kickoff-total], [returns-kickoff-yards], [returns-kickoff-average],
           [returns-kickoff-longest], [returns-punt-total], [returns-punt-yards],
           [returns-punt-average], [returns-punt-longest], [fair-catches]
      FROM (SELECT [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (passing_touchdowns, rushing_touchdowns, receiving_touchdowns,
                                            interceptions_returned_touchdowns, fumbles_recovered_touchdowns,
                                            kickoff_return_touchdowns, punt_return_touchdowns, total_touchdowns,
                                            field_goals_succeeded, extra_point_kicks_succeeded, [points-scored-for],
                                            [points-scored-for-per-game], passing_plays_completed, passing_plays_attempted,
                                            [passes-percentage], passer_rating, passing_yards,
                                            [passes-average-yards-per], [passes-yards-gross-per-game], passing_longest_yards,
                                            passing_plays_intercepted, passing_plays_sacked,
                                            rushing_plays, rushing_net_yards, [rushing-average-yards-per],
                                            rushing_longest_yards, [rushes-yards-per-game], [fumbles-committed],
                                            [receptions-total], [receptions-yards], [receptions-average-yards-per],
                                            [receptions-longest], [receptions-yards-per-game],
                                            [tackles-solo], [tackles-assists], [tackles-total], [sacks-total],
                                            [interceptions-total], [interceptions-yards], [interceptions-longest],
                                            [fumbles-forced], [fumbles-opposing-recovered],
                                            [field-goal-attempts], [field-goals-percentage], [extra-points-attempts],
                                            [extra-points-percentage],
                                            [punts-total], [punts-yards-gross], [punts-longest], [punts-average],
                                            [punts-inside-20], [touchbacks-total],
                                            [returns-kickoff-total], [returns-kickoff-yards], [returns-kickoff-average],
                                            [returns-kickoff-longest], [returns-punt-total], [returns-punt-yards],
                                            [returns-punt-average], [returns-punt-longest], [fair-catches])) AS p

    -- scoring
    UPDATE @football
       SET scoring = 1
     WHERE [points-scored-for] <> '0'

    UPDATE @football
       SET passing_touchdowns = ISNULL(passing_touchdowns, ''),
           rushing_touchdowns = ISNULL(rushing_touchdowns, ''),
           receiving_touchdowns = ISNULL(receiving_touchdowns, ''),
           interceptions_returned_touchdowns = ISNULL(interceptions_returned_touchdowns, ''),
           fumbles_recovered_touchdowns = ISNULL(fumbles_recovered_touchdowns, ''),
           kickoff_return_touchdowns = ISNULL(kickoff_return_touchdowns, ''),
           punt_return_touchdowns = ISNULL(punt_return_touchdowns, ''),
           total_touchdowns = ISNULL(total_touchdowns, ''),
           field_goals_succeeded = ISNULL(field_goals_succeeded, ''),
           extra_point_kicks_succeeded = ISNULL(extra_point_kicks_succeeded, ''),
           [points-scored-for] = ISNULL([points-scored-for], ''),
           [points-scored-for-per-game] = ISNULL([points-scored-for-per-game], '')
     WHERE scoring = 1

    -- passing
    UPDATE @football
       SET passing = 1
     WHERE passing_plays_attempted <> '0'

    UPDATE @football
       SET passing_plays_completed = ISNULL(passing_plays_completed, ''),
           passing_plays_attempted = ISNULL(passing_plays_attempted, ''),
           [passes-percentage] = ISNULL([passes-percentage], ''),
           passer_rating = ISNULL(passer_rating, ''),
           passing_yards = ISNULL(passing_yards, ''),
           [passes-average-yards-per] = ISNULL([passes-average-yards-per], ''),
           [passes-yards-gross-per-game] = ISNULL([passes-yards-gross-per-game], ''),
           passing_longest_yards = ISNULL(passing_longest_yards, ''),
           passing_touchdowns = ISNULL(passing_touchdowns, ''),
           passing_plays_intercepted = ISNULL(passing_plays_intercepted, ''),
           passing_plays_sacked = ISNULL(passing_plays_sacked, '')
     WHERE passing = 1

    -- rushing
    UPDATE @football
       SET rushing = 1
     WHERE rushing_plays <> '0'

    UPDATE @football
       SET rushing_plays = ISNULL(rushing_plays, ''),
           rushing_net_yards = ISNULL(rushing_net_yards, ''),
           [rushing-average-yards-per] = ISNULL([rushing-average-yards-per], ''),
           rushing_longest_yards = ISNULL(rushing_longest_yards, ''),
           [rushes-yards-per-game] = ISNULL([rushes-yards-per-game], ''),
           rushing_touchdowns = ISNULL(rushing_touchdowns, ''),
           [fumbles-committed] = ISNULL([fumbles-committed], '')
     WHERE rushing = 1

    -- receiving
    UPDATE @football
       SET receiving = 1
     WHERE [receptions-total] <> '0'

    UPDATE @football
       SET [receptions-total] = ISNULL([receptions-total], ''),
           [receptions-yards] = ISNULL([receptions-yards], ''),
           [receptions-average-yards-per] = ISNULL([receptions-average-yards-per], ''),
           [receptions-longest] = ISNULL([receptions-longest], ''),
           [receptions-yards-per-game] = ISNULL([receptions-yards-per-game], ''),
           receiving_touchdowns = ISNULL(receiving_touchdowns, '')
     WHERE receiving = 1

    -- defense
    UPDATE @football
       SET defense = 1
     WHERE [tackles-total] <> '0' OR [sacks-total] <> '0' OR [interceptions-total] <> '0' OR
           [fumbles-forced] <> '0' OR [fumbles-opposing-recovered] <> '0'

    UPDATE @football
       SET [tackles-solo] = ISNULL([tackles-solo], ''),
           [tackles-assists] = ISNULL([tackles-assists], ''),
           [tackles-total] = ISNULL([tackles-total], ''),
           [sacks-total] = ISNULL([sacks-total], ''),
           [interceptions-total] = ISNULL([interceptions-total], ''),
           [interceptions-yards] = ISNULL([interceptions-yards], ''),
           [interceptions-longest] = ISNULL([interceptions-longest], ''),
           interceptions_returned_touchdowns = ISNULL(interceptions_returned_touchdowns, ''),
           [fumbles-forced] = ISNULL([fumbles-forced], ''),
           [fumbles-opposing-recovered] = ISNULL([fumbles-opposing-recovered], ''),
           fumbles_recovered_touchdowns = ISNULL(fumbles_recovered_touchdowns, '')
     WHERE defense = 1

    -- kicking
    UPDATE @football
       SET kicking = 1
     WHERE [field-goal-attempts] <> '0' OR [extra-points-attempts] <> '0'

    UPDATE @football
       SET field_goals_succeeded = ISNULL(field_goals_succeeded, ''),
           [field-goal-attempts] = ISNULL([field-goal-attempts], ''),
           [field-goals-percentage] = ISNULL([field-goals-percentage], ''),
           extra_point_kicks_succeeded = ISNULL(extra_point_kicks_succeeded, ''),
           [extra-points-attempts] = ISNULL([extra-points-attempts], ''),
           [extra-points-percentage] = ISNULL([extra-points-percentage], '')
     WHERE kicking = 1

    -- punting
    UPDATE @football
       SET punting = 1
     WHERE [punts-total] <> '0'

    UPDATE @football
       SET [punts-total] = ISNULL([punts-total], ''),
           [punts-yards-gross] = ISNULL([punts-yards-gross], ''),
           [punts-longest] = ISNULL([punts-longest], ''),
           [punts-average] = ISNULL([punts-average], ''),
           [punts-inside-20] = ISNULL([punts-inside-20], ''),
           [touchbacks-total] = ISNULL([touchbacks-total], '')
     WHERE punting = 1

    -- returning
    UPDATE @football
       SET returning = 1
     WHERE [returns-kickoff-total] <> '0' OR [returns-punt-total] <> '0'

    UPDATE @football
       SET [returns-kickoff-total] = ISNULL([returns-kickoff-total], ''),
           [returns-kickoff-yards] = ISNULL([returns-kickoff-yards], ''),
           [returns-kickoff-average] = ISNULL([returns-kickoff-average], ''),
           [returns-kickoff-longest] = ISNULL([returns-kickoff-longest], ''),
           kickoff_return_touchdowns = ISNULL(kickoff_return_touchdowns, ''),
           [returns-punt-total] = ISNULL([returns-punt-total], ''),
           [returns-punt-yards] = ISNULL([returns-punt-yards], ''),
           [returns-punt-average] = ISNULL([returns-punt-average], ''),
           [returns-punt-longest] = ISNULL([returns-punt-longest], ''),
           punt_return_touchdowns = ISNULL(punt_return_touchdowns, ''),
           [fair-catches] = ISNULL([fair-catches], '')
     WHERE returning = 1



    SELECT
    (
	    SELECT id, uniform_number, position, height, [weight], head_shot, first_name, last_name, college, dob, experience, class
    	  FROM @player
    	 WHERE player_key = @player_key
           FOR XML RAW('player'), TYPE
    ),
    (
        SELECT passing_touchdowns, rushing_touchdowns, receiving_touchdowns, interceptions_returned_touchdowns,
               fumbles_recovered_touchdowns, kickoff_return_touchdowns, punt_return_touchdowns, total_touchdowns
               field_goals_succeeded, extra_point_kicks_succeeded, [points-scored-for], [points-scored-for-per-game]
          FROM @football
         WHERE scoring = 1
           FOR XML RAW('scoring'), TYPE
    ),
    (
        SELECT passing_plays_completed, passing_plays_attempted, [passes-percentage], passer_rating, passing_yards,
               [passes-average-yards-per], [passes-yards-gross-per-game], passing_longest_yards, passing_touchdowns,
               passing_plays_intercepted, passing_plays_sacked
          FROM @football
         WHERE passing = 1
           FOR XML RAW('passing'), TYPE
    ),
    (
        SELECT rushing_plays, rushing_net_yards, [rushing-average-yards-per], rushing_longest_yards,
               [rushes-yards-per-game], rushing_touchdowns, [fumbles-committed]
          FROM @football
         WHERE rushing = 1
           FOR XML RAW('rushing'), TYPE
    ),
    (
        SELECT [receptions-total], [receptions-yards], [receptions-average-yards-per],
               [receptions-longest], [receptions-yards-per-game], receiving_touchdowns
          FROM @football
         WHERE receiving = 1
           FOR XML RAW('receiving'), TYPE
    ),
    (
        SELECT [tackles-solo], [tackles-assists], [tackles-total], [sacks-total], [interceptions-total],
               [interceptions-yards], [interceptions-longest], interceptions_returned_touchdowns,
               [fumbles-forced], [fumbles-opposing-recovered], fumbles_recovered_touchdowns
          FROM @football
         WHERE defense = 1
           FOR XML RAW('defense'), TYPE
    ),
    (
        SELECT field_goals_succeeded, [field-goal-attempts], [field-goals-percentage],
               extra_point_kicks_succeeded, [extra-points-attempts], [extra-points-percentage]
          FROM @football
         WHERE kicking = 1
           FOR XML RAW('kicking'), TYPE
    ),
    (
        SELECT [punts-total], [punts-yards-gross], [punts-longest], [punts-average], [punts-inside-20], [touchbacks-total]
          FROM @football
         WHERE punting = 1
           FOR XML RAW('punting'), TYPE
    ),
    (
        SELECT [returns-kickoff-total], [returns-kickoff-yards], [returns-kickoff-average], [returns-kickoff-longest],
               kickoff_return_touchdowns, [returns-punt-total], [returns-punt-yards], [returns-punt-average],
               [returns-punt-longest], punt_return_touchdowns, [fair-catches]
          FROM @football
         WHERE returning = 1
           FOR XML RAW('returning'), TYPE
    )
    FOR XML RAW('root'), TYPE

    SET NOCOUNT OFF
END 

GO
