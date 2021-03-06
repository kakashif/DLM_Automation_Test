USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventBoxscore_football_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventBoxscore_football_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 07/29/2014
-- Description:	get football boxscore
-- Update:		09/02/2014 - thlam - remove the space on punt_return_yards
--              09/16/2014 - John Lin - update some calculations
--              07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)    
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)
    
    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status, @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 


    IF (@event_status NOT IN ('mid-event', 'intermission', 'weather-delay', 'post-event'))
    BEGIN
        SELECT
	    (
            SELECT '' AS boxscore
               FOR XML PATH(''), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    INSERT INTO @tables (table_name, table_display)
    VALUES ('passing', 'Passing'), ('rushing', 'Rushing'), ('receiving', 'Receiving'), ('tackles', 'Tackles'),
           ('interceptions', 'Interceptions'), ('fumbles', 'Fumbles'), ('punting', 'Punting'),
           ('punt_returns', 'Punt Returns'), ('kicking', 'Kicking'), ('kick_returns', 'Kick Returns')

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('passing', 'player_display', 'PLAYER'),
           ('passing', 'passing-plays-completed-attempted', 'C/ATT'),
           ('passing', 'passing_yards', 'YDS'),
           ('passing', 'passing-percentage', 'PCT%'),
           ('passing', 'passing_touchdowns', 'TD'),
           ('passing', 'passing_plays_intercepted', 'INT'),
           
           ('rushing', 'player_display', 'PLAYER'),
           ('rushing', 'rushing_plays', 'CAR'),
           ('rushing', 'rushing_net_yards', 'YDS'),
           ('rushing', 'rushing-average-yards', 'AVG'),
           ('rushing', 'rushing_touchdowns', 'TD'),
--           ('rushing', 'rushing_longest_yards', 'LG'),
           
           ('receiving', 'player_display', 'PLAYER'),
           ('receiving', 'receiving_receptions', 'REC'),
           ('receiving', 'receiving_yards', 'YDS'),
           ('receiving', 'receiving-average-yards', 'AVG'),
           ('receiving', 'receiving_touchdowns', 'TD'),
--           ('receiving', 'receiving_longest_yards', 'LG'),
           
           ('tackles', 'player_display', 'PLAYER'),
           ('tackles', 'tackles-total', 'TKL'),
           ('tackles', 'tackles_solo', 'SOL'),
           ('tackles', 'tackles_assists', 'AST'),
           ('tackles', 'defense-sacks-yards', 'SK-YD'),

           ('interceptions', 'player_display', 'PLAYER'),
           ('interceptions', 'defense_interceptions', 'INT'),
           ('interceptions', 'defense_interception_yards', 'YDS'),
           ('interceptions', 'interception_returned_average_yards', 'YDS'),
--           ('interceptions', 'interception_returned_longest_yards', 'LG'),
           ('interceptions', 'interceptions_returned_touchdowns', 'TD'),
           
           ('fumbles', 'player_display', 'PLAYER'),
           ('fumbles', 'fumbles', 'FUM'),
           ('fumbles', 'fumbles_lost', 'LOST'),
           ('fumbles', 'fumbles_recovered_lost_by_opposition', 'REC'),
           ('fumbles', 'fumbles_yards', 'YDS'),
           
           ('punting', 'player_display', 'PLAYER'),
           ('punting', 'punting_plays', 'TOT'),
           ('punting', 'punting_gross_yards', 'YDS'),
           ('punting', 'punting-average', 'AVG'),
           ('punting', 'punting_inside_twenty', '-20'),
           
           ('punt_returns', 'player_display', 'PLAYER'),
           ('punt_returns', 'punt_returns', 'TOT'),
           ('punt_returns', 'punt_return_yards', 'YDS'),
           ('punt_returns', 'punt-return-average', 'AVG'),
--           ('punt_returns', 'punt_return_longest_yards', 'LG'),
           ('punt_returns', 'punt_return_touchdowns', 'TD'),
           
           ('kicking', 'player_display', 'PLAYER'),
           ('kicking', 'field-goals-succeeded-attempted', 'FG'),
--           ('kicking', 'field_goals_succeeded_longest_yards', 'LG'),
           ('kicking', 'extra-point-kicks-succeeded-attempted', 'XP'),
           
           ('kick_returns', 'player_display', 'PLAYER'),
           ('kick_returns', 'kickoff_returns', 'TOT'),
           ('kick_returns', 'kickoff_return_yards', 'YDS'),
           ('kick_returns', 'kickoff-return-average', 'AVG'),
--           ('kick_returns', 'kickoff_return_longest_yards', 'LG'),
           ('kick_returns', 'kickoff_return_touchdowns', 'TD')
    
    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_football
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND event_key = @event_key
             
    DECLARE @football TABLE
	(
		team_key       VARCHAR(100),
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
		position_event VARCHAR(100),
        -- passing --
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        passing_touchdowns        INT,
        passing_plays_intercepted INT,
        -- rushing --
        rushing_plays         INT,
        rushing_net_yards     INT,
        rushing_touchdowns    INT,
        rushing_longest_yards INT,
        -- receiving --
        receiving_receptions    INT,
        receiving_yards         INT,
        receiving_touchdowns    INT,
        receiving_longest_yards INT,
        -- tackles --
        tackles_solo        INT,
        tackles_assists     INT,
        defense_sacks       VARCHAR(100),
        defense_sacks_yards INT,
        -- interceptions --
        defense_interceptions               INT,
        defense_interception_yards          INT,
        interception_returned_longest_yards INT,
        interceptions_returned_touchdowns   INT,
        -- fumbles --
        fumbles                              INT,
        fumbles_lost                         INT,
        fumbles_recovered_lost_by_opposition INT,
        fumbles_yards                        INT,
        -- punting --
        punting_plays         INT,
        punting_gross_yards   INT,
        punting_inside_twenty INT,
        -- punt_returns --
        punt_returns              INT,
        punt_return_yards         INT,
        punt_return_longest_yards INT,
        punt_return_touchdowns    INT,
        -- kicking --
        field_goals_succeeded       INT,
        field_goals_attempted       INT,
        field_goal_longest          INT,
        extra_point_kicks_succeeded INT,
        extra_point_kicks_attempted INT,
        -- kick-returns --
        kickoff_returns              INT,
        kickoff_return_yards         INT,
        kickoff_return_longest_yards VARCHAR(100),
        kickoff_return_touchdowns    INT
	)

                           
	INSERT INTO @football (player_key, team_key, position_event,
	                       passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                           rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                           receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,
                           tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards,
                           defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                           fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards,
                           punting_plays, punting_gross_yards, punting_inside_twenty,
                           punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns,
                           field_goals_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted,
                           kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns)
    SELECT p.player_key, p.team_key, position_event,
           ISNULL(passing_plays_completed, 0), ISNULL(passing_plays_attempted, 0), ISNULL(passing_yards, 0), ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0),
           ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_touchdowns, 0), ISNULL(rushing_longest_yards, 0),
           ISNULL(receiving_receptions, 0), ISNULL(receiving_yards, 0), ISNULL(receiving_touchdowns, 0), ISNULL(receiving_longest_yards, 0),
           ISNULL(tackles_solo, 0), ISNULL(tackles_assists, 0), ISNULL(defense_sacks, 0), ISNULL(defense_sacks_yards, 0),
           ISNULL(defense_interceptions, 0), ISNULL(defense_interception_yards, 0), ISNULL(interception_returned_longest_yards, 0), ISNULL(interceptions_returned_touchdowns, 0),
           ISNULL(fumbles, 0), ISNULL(fumbles_lost, 0), ISNULL(fumbles_recovered_lost_by_opposition, 0), ISNULL(fumbles_yards, 0),
           ISNULL(punting_plays, 0), ISNULL(punting_gross_yards, 0), ISNULL(punting_inside_twenty, 0),
           ISNULL(punt_returns, 0), ISNULL(punt_return_yards, 0), ISNULL(punt_return_longest_yards, 0), ISNULL(punt_return_touchdowns, 0),
           ISNULL(field_goals_succeeded, 0), ISNULL(field_goals_attempted, 0), ISNULL(field_goal_longest, 0), ISNULL(extra_point_kicks_succeeded, 0), ISNULL(extra_point_kicks_attempted, 0),
           ISNULL(kickoff_returns, 0), ISNULL(kickoff_return_yards, 0), ISNULL(kickoff_return_longest_yards, 0), ISNULL(kickoff_return_touchdowns, 0)
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (position_event,
                                               passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                                               rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                                               receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,
                                               tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards,
                                               defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                                               fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards,
                                               punting_plays, punting_gross_yards, punting_inside_twenty,
                                               punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns,
                                               field_goals_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted,
                                               kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns)) AS p


    -- player
	UPDATE b
	   SET b.player_display = (CASE
	                              WHEN s.last_name IS NOT NULL THEN s.first_name + ' ' + s.last_name
	                           END)
	  FROM @football AS b
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = b.player_key AND s.first_name <> 'TEAM'

    DELETE @football
     WHERE player_display IS NULL


    -- passing
    DECLARE @passing TABLE
    (
        team_key                  VARCHAR(100),
        player_display            VARCHAR(100),
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        [passing-percentage]      VARCHAR(100),
        passing_touchdowns        INT,
        passing_plays_intercepted INT
    )
	INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted)
	SELECT team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards,
	       CAST((100 * CAST(passing_plays_completed AS FLOAT) / passing_plays_attempted) AS DECIMAL(4, 1)),
	       passing_touchdowns, passing_plays_intercepted
	  FROM @football
     WHERE passing_plays_attempted > 0

	INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted)
    SELECT @away_team_key, 'TEAM', SUM(passing_plays_completed), SUM(passing_plays_attempted), SUM(passing_yards),
           CAST((100 * CAST(SUM(passing_plays_completed) AS FLOAT) / SUM(passing_plays_attempted)) AS DECIMAL(4, 1)),
           SUM(passing_touchdowns), SUM(passing_plays_intercepted)
      FROM @passing
     WHERE team_key = @away_team_key 

	INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted)
    SELECT @home_team_key, 'TEAM', SUM(passing_plays_completed), SUM(passing_plays_attempted), SUM(passing_yards),
           CAST((100 * CAST(SUM(passing_plays_completed) AS FLOAT) / SUM(passing_plays_attempted)) AS DECIMAL(4 ,1)),
           SUM(passing_touchdowns), SUM(passing_plays_intercepted)
      FROM @passing
     WHERE team_key = @home_team_key 

    -- rushing
    DECLARE @rushing TABLE
    (
        team_key                VARCHAR(100),
        player_display          VARCHAR(100),
        rushing_plays           INT,
        rushing_net_yards       INT,
        [rushing-average-yards] VARCHAR(100),
        rushing_touchdowns      INT,
        rushing_longest_yards   INT
    )
	INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns, rushing_longest_yards)
	SELECT team_key, player_display, rushing_plays, rushing_net_yards,
	       CAST(((CAST(rushing_net_yards AS FLOAT) / rushing_plays)) AS DECIMAL(4, 1)),
	       rushing_touchdowns, rushing_longest_yards
	  FROM @football
     WHERE rushing_plays > 0

	INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns, rushing_longest_yards)
    SELECT @away_team_key, 'TEAM', SUM(rushing_plays), SUM(rushing_net_yards),
           CAST((CAST(SUM(rushing_net_yards) AS FLOAT) / SUM(rushing_plays)) AS DECIMAL(4,1)),
           SUM(rushing_touchdowns), MAX(rushing_longest_yards)
      FROM @rushing
     WHERE team_key = @away_team_key 

	INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns, rushing_longest_yards)
    SELECT @home_team_key, 'TEAM', SUM(rushing_plays), SUM(rushing_net_yards),
           CAST((CAST(SUM(rushing_net_yards) AS FLOAT) / SUM(rushing_plays)) AS DECIMAL(4, 1)),
           SUM(rushing_touchdowns), MAX(rushing_longest_yards)
      FROM @rushing
     WHERE team_key = @home_team_key 

    -- receiving
    DECLARE @receiving TABLE
    (
        team_key                  VARCHAR(100),
        player_display            VARCHAR(100),
        receiving_receptions      INT,
        receiving_yards           INT,
        [receiving-average-yards] VARCHAR(100),
        receiving_touchdowns      INT,
        receiving_longest_yards   INT
    )
	INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards)
	SELECT team_key, player_display, receiving_receptions, receiving_yards,
	       CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(4, 1)),
	       receiving_touchdowns, receiving_longest_yards
	  FROM @football
     WHERE receiving_receptions > 0

	INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards)
	SELECT @away_team_key, 'TEAM', SUM(receiving_receptions), SUM(receiving_yards),
	      CAST((CAST(SUM(receiving_yards) AS FLOAT) / SUM(receiving_receptions)) AS DECIMAL(4, 1)),
	      SUM(receiving_touchdowns), MAX(receiving_longest_yards)
	  FROM @receiving
	 WHERE team_key = @away_team_key 

	INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards)
	SELECT @home_team_key, 'TEAM', SUM(receiving_receptions), SUM(receiving_yards),
	       CAST((CAST(SUM(receiving_yards) AS FLOAT) / SUM(receiving_receptions)) AS DECIMAL(4, 1)),
	       SUM(receiving_touchdowns), MAX(receiving_longest_yards)
	  FROM @receiving
	 WHERE team_key = @home_team_key 

    -- tackles
    DECLARE @tackles TABLE
    (
        team_key            VARCHAR(100),
        player_display      VARCHAR(100),
        tackles_total       INT,
        tackles_solo        INT,
        tackles_assists     INT,
        defense_sacks       VARCHAR(100),
        defense_sacks_yards INT
    )
    IF (@leagueName = 'nfl')
    BEGIN
	    INSERT INTO @tackles (team_key, player_display, tackles_total, tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards)
    	SELECT team_key, player_display, tackles_solo + tackles_assists, tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards
	      FROM @football
         WHERE (tackles_solo + tackles_assists) > 0 OR CAST(defense_sacks AS FLOAT) > 0

    	INSERT INTO @tackles (team_key, player_display, tackles_total, tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards)
        SELECT @away_team_key, 'TEAM', SUM(tackles_total), SUM(tackles_solo), SUM(tackles_assists), SUM(CAST(defense_sacks AS FLOAT)), SUM(defense_sacks_yards)
          FROM @tackles
         WHERE team_key = @away_team_key 

    	INSERT INTO @tackles (team_key, player_display, tackles_total, tackles_solo, tackles_assists, defense_sacks, defense_sacks_yards)
        SELECT @home_team_key, 'TEAM', SUM(tackles_total), SUM(tackles_solo), SUM(tackles_assists), SUM(CAST(defense_sacks AS FLOAT)), SUM(defense_sacks_yards)
          FROM @tackles
         WHERE team_key = @home_team_key 
    END
    
    -- interceptions
    DECLARE @interceptions TABLE
    (
        team_key                            VARCHAR(100),
        player_display                      VARCHAR(100),
        defense_interceptions               INT,
        defense_interception_yards          INT,
        interception_returned_longest_yards INT,
        interceptions_returned_touchdowns   INT
    )
	INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
	SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns
	  FROM @football
     WHERE defense_interceptions > 0

	INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
    SELECT @away_team_key, 'TEAM', SUM(defense_interceptions), SUM(defense_interception_yards), MAX(interception_returned_longest_yards), SUM(interceptions_returned_touchdowns)
      FROM @interceptions
     WHERE team_key = @away_team_key 

	INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
    SELECT @home_team_key, 'TEAM', SUM(defense_interceptions), SUM(defense_interception_yards), MAX(interception_returned_longest_yards), SUM(interceptions_returned_touchdowns)
      FROM @interceptions
     WHERE team_key = @home_team_key 

    -- fumbles
    DECLARE @fumbles TABLE
    (
        team_key                             VARCHAR(100),
        player_display                       VARCHAR(100),
        fumbles                              INT,
        fumbles_lost                         INT,
        fumbles_recovered_lost_by_opposition INT,
        fumbles_yards                        INT
    )
	INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards)
	SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards
	  FROM @football
     WHERE fumbles > 0 OR fumbles_lost > 0 OR  fumbles_recovered_lost_by_opposition > 0

	INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards)
    SELECT @away_team_key, 'TEAM', SUM(fumbles), SUM(fumbles_lost), SUM(fumbles_recovered_lost_by_opposition), SUM(fumbles_yards)
      FROM @fumbles
     WHERE team_key = @away_team_key 

	INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards)
    SELECT @home_team_key, 'TEAM', SUM(fumbles), SUM(fumbles_lost), SUM(fumbles_recovered_lost_by_opposition), SUM(fumbles_yards)
      FROM @fumbles
     WHERE team_key = @home_team_key 

    -- punting
    DECLARE @punting TABLE
    (
        team_key              VARCHAR(100),
        player_display        VARCHAR(100),
        punting_plays         INT,
        punting_gross_yards   INT,
        [punting-average]     VARCHAR(100),
        punting_inside_twenty INT
    )
	INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty)
	SELECT team_key, player_display, punting_plays, punting_gross_yards,
	       CAST((CAST(punting_gross_yards AS FLOAT) / punting_plays) AS DECIMAL(4, 1)),
	       punting_inside_twenty
	  FROM @football
     WHERE punting_plays > 0

	INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty)
    SELECT @away_team_key, 'TEAM', SUM(punting_plays), SUM(punting_gross_yards),
           CAST((CAST(SUM(punting_gross_yards) AS FLOAT) / SUM(punting_plays)) AS DECIMAL(4, 1)),
           SUM(punting_inside_twenty)
      FROM @punting
     WHERE team_key = @away_team_key 

	INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty)
    SELECT @home_team_key, 'TEAM', SUM(punting_plays), SUM(punting_gross_yards),
           CAST((CAST(SUM(punting_gross_yards) AS FLOAT) / SUM(punting_plays)) AS DECIMAL(4,1)),
           SUM(punting_inside_twenty)
      FROM @punting
     WHERE team_key = @home_team_key 

    -- punt_returns
    DECLARE @punt_returns TABLE
    (
        team_key                  VARCHAR(100),
        player_display            VARCHAR(100),
        punt_returns              INT,
        punt_return_yards         INT,
        [punt-return-average]     VARCHAR(100),
        punt_return_longest_yards INT,
        punt_return_touchdowns    INT
    )
	INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns)
	SELECT team_key, player_display, punt_returns, punt_return_yards,
	       CAST((CAST(punt_return_yards AS FLOAT) / punt_returns) AS DECIMAL(4, 1)),
	       punt_return_longest_yards, punt_return_touchdowns
	  FROM @football
     WHERE punt_returns > 0
           
	INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns)
	SELECT @away_team_key, 'TEAM', SUM(punt_returns), SUM(punt_return_yards),
	       CAST((CAST(SUM(punt_return_yards) AS FLOAT) / SUM(punt_returns)) AS DECIMAL(4, 1)),
	       MAX(punt_return_longest_yards), SUM(punt_return_touchdowns)
	  FROM @punt_returns
	 WHERE team_key = @away_team_key 

	INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns)
	SELECT @home_team_key, 'TEAM', SUM(punt_returns), SUM(punt_return_yards),
	       CAST((CAST(SUM(punt_return_yards) AS FLOAT) / SUM(punt_returns)) AS DECIMAL(4, 1)),
	       MAX(punt_return_longest_yards), SUM(punt_return_touchdowns)
	  FROM @punt_returns
	 WHERE team_key = @home_team_key 

    -- kicking
    DECLARE @kicking TABLE
    (
        team_key                    VARCHAR(100),
        player_display              VARCHAR(100),
        field_goal_succeeded        INT,
        field_goals_attempted       INT,
		field_goal_longest          INT,
        extra_point_kicks_succeeded INT,
        extra_point_kicks_attempted INT
    )
	INSERT INTO @kicking (team_key, player_display, field_goal_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted)
	SELECT team_key, player_display, field_goals_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted
	  FROM @football
     WHERE field_goals_attempted > 0 OR extra_point_kicks_attempted > 0

	INSERT INTO @kicking (team_key, player_display, field_goal_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted)
    SELECT @away_team_key, 'TEAM', SUM(field_goal_succeeded), SUM(field_goals_attempted), MAX(field_goal_longest), SUM(extra_point_kicks_succeeded), SUM(extra_point_kicks_attempted)
      FROM @kicking
     WHERE team_key = @away_team_key 

	INSERT INTO @kicking (team_key, player_display, field_goal_succeeded, field_goals_attempted, field_goal_longest, extra_point_kicks_succeeded, extra_point_kicks_attempted)
    SELECT @home_team_key, 'TEAM', SUM(field_goal_succeeded), SUM(field_goals_attempted), MAX(field_goal_longest), SUM(extra_point_kicks_succeeded), SUM(extra_point_kicks_attempted)
      FROM @kicking
     WHERE team_key = @home_team_key 

    -- kick_returns
    DECLARE @kick_returns TABLE
    (
        team_key                     VARCHAR(100),
        player_display               VARCHAR(100),
        kickoff_returns              INT,
        kickoff_return_yards         INT,
        [kickoff-return-average]     VARCHAR(100),
        kickoff_return_longest_yards INT,
        kickoff_return_touchdowns    INT
    )
	INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns)
	SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, 
	       CAST((CAST(kickoff_return_yards AS FLOAT) / kickoff_returns) AS DECIMAL(4, 1)),
	       kickoff_return_longest_yards, kickoff_return_touchdowns
	  FROM @football
     WHERE kickoff_returns > 0

    INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns)
	SELECT @away_team_key, 'TEAM', SUM(kickoff_returns), SUM(kickoff_return_yards),
	       CAST((CAST(SUM(kickoff_return_yards) AS FLOAT) / SUM(kickoff_returns)) AS DECIMAL(4, 1)),
	       MAX(kickoff_return_longest_yards), SUM(kickoff_return_touchdowns)
	  FROM @kick_returns
	 WHERE team_key = @away_team_key 

	INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns)
	SELECT @home_team_key, 'TEAM', SUM(kickoff_returns), SUM(kickoff_return_yards),
	       CAST((CAST(SUM(kickoff_return_yards) AS FLOAT) / SUM(kickoff_returns)) AS DECIMAL(4, 1)),
	       MAX(kickoff_return_longest_yards), SUM(kickoff_return_touchdowns)
	  FROM @kick_returns
	 WHERE team_key = @home_team_key 

    -- officials
    DECLARE @referee TABLE
	(
		position VARCHAR(100),
		judge VARCHAR(100),
		[order] INT
	)

	INSERT INTO @referee (position, judge)
	SELECT [column], value
	  FROM dbo.SMG_Scores
	 WHERE event_key = @event_key AND column_type = 'officials'

	UPDATE @referee
	   SET [order] = CASE
	                     WHEN position = 'Referee' THEN 1
	                     WHEN position = 'Umpire' THEN 2
	                     WHEN position = 'Head Linesman' THEN 3
	                     WHEN position = 'Line Judge' THEN 4
	                     WHEN position = 'Side Judge' THEN 5
	                     WHEN position = 'Back Judge' THEN 6
	                     WHEN position = 'Field Judge' THEN 7
	                     ELSE 99
	                 END





	SELECT
	(
		SELECT t.table_name, t.table_display,
		       (
				   SELECT c.column_name, c.column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   -- away
               (
                   SELECT player_display, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS 'passing-plays-completed-attempted'
                     FROM @passing
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'passing'
                    ORDER BY passing_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS 'passing-plays-completed-attempted'
                     FROM @passing
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'passing'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns,rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'rushing'
                    ORDER BY rushing_net_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns,rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'rushing'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'receiving'
                    ORDER BY receiving_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'receiving'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, tackles_solo, tackles_assists,
                          defense_sacks + '-' + CAST(defense_sacks_yards AS VARCHAR) AS defense_defense_sacks_yards
                     FROM @tackles
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'tackles'
                    ORDER BY tackles_total DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, tackles_solo, tackles_assists,
                          defense_sacks + '-' + CAST(defense_sacks_yards AS VARCHAR) AS defense_defense_sacks_yards
                     FROM @tackles
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'tackles'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                          CAST(CAST(defense_interception_yards AS FLOAT) / defense_interceptions AS DECIMAL(3, 1)) AS interceptions_average
                     FROM @interceptions
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'interceptions'
                    ORDER BY defense_interceptions DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                          CAST(CAST(defense_interception_yards AS FLOAT) / defense_interceptions AS DECIMAL(3, 1)) AS interceptions_average
                     FROM @interceptions
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'interceptions'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'fumbles'
                    ORDER BY fumbles DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'fumbles'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'punting'
                    ORDER BY punting_gross_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'punting'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'punt_returns'
                    ORDER BY punt_return_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'punt_returns'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goal_longest,
                          CAST(field_goal_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS 'field-goals-succeeded-attempted',
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS 'extra-point-kicks-succeeded-attempted'
                     FROM @kicking
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'kicking'
                    ORDER BY field_goal_succeeded DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goal_longest,
                          CAST(field_goal_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS 'field-goals-succeeded-attempted',
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS 'extra-point-kicks-succeeded-attempted'
                     FROM @kicking
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'kicking'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'kick_returns'
                    ORDER BY kickoff_return_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'kick_returns'
                      FOR XML PATH('away_total'), TYPE
               ),
               -- home               
               (
                   SELECT player_display, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS 'passing-plays-completed-attempted'
                     FROM @passing
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'passing'
                    ORDER BY passing_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, passing_yards, [passing-percentage], passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS 'passing-plays-completed-attempted'
                     FROM @passing
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'passing'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns,rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'rushing'
                    ORDER BY rushing_net_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, [rushing-average-yards], rushing_touchdowns,rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'rushing'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'receiving'
                    ORDER BY receiving_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, [receiving-average-yards], receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'receiving'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, tackles_solo, tackles_assists,
                          defense_sacks + '-' + CAST(defense_sacks_yards AS VARCHAR) AS defense_defense_sacks_yards
                     FROM @tackles
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'tackles'
                    ORDER BY tackles_total DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, tackles_solo, tackles_assists,
                          defense_sacks + '-' + CAST(defense_sacks_yards AS VARCHAR) AS defense_defense_sacks_yards
                     FROM @tackles
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'tackles'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                          CAST(CAST(defense_interception_yards AS FLOAT) / defense_interceptions AS DECIMAL(3, 1)) AS interceptions_average
                     FROM @interceptions
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'interceptions'
                    ORDER BY defense_interceptions DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                          CAST(CAST(defense_interception_yards AS FLOAT) / defense_interceptions AS DECIMAL(3, 1)) AS interceptions_average
                     FROM @interceptions
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'interceptions'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'fumbles'
                    ORDER BY fumbles DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'fumbles'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'punting'
                    ORDER BY punting_gross_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, [punting-average], punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'punting'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'punt_returns'
                    ORDER BY punt_return_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'punt_returns'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goal_longest,
                          CAST(field_goal_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS 'field-goals-succeeded-attempted',
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS 'extra-point-kicks-succeeded-attempted'
                     FROM @kicking
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'kicking'
                    ORDER BY field_goal_succeeded DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goal_longest,
                          CAST(field_goal_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS 'field-goals-succeeded-attempted',
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS 'extra-point-kicks-succeeded-attempted'
                     FROM @kicking
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'kicking'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'kick_returns'
                    ORDER BY kickoff_return_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'kick_returns'
                      FOR XML PATH('home_total'), TYPE
               )
   		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE		   
	)
	FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
