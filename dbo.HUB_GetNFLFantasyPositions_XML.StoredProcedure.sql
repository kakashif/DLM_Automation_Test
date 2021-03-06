USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLFantasyPositions_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNFLFantasyPositions_XML] 
	@seasonKey VARCHAR(10) = '2014',
	@subseasonKey VARCHAR(100) = 'season-regular',
	@startweek VARCHAR(10) = '1',
	@endweek VARCHAR(10) = '1',
    @range VARCHAR(100) = 'all',
    @position VARCHAR(10) = 'all'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 09/18/2014
-- Description: Get NFL Fantasy Positions Data
-- Update:		10/02/2014 - pkamat: Increased points data type to DECIMAL(15,2)
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    
    DECLARE @leagueName VARCHAR(100) = 'nfl';
    DECLARE @leagueKey VARCHAR(100);
    
   	SELECT @leagueKey = league_display_name
	  FROM dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName);

	--Get default subseason key
	IF (@subseasonKey IS NULL OR @subseasonKey = '')
	BEGIN
		SET @subseasonKey = 'season-regular';
	END

	DECLARE @editor VARCHAR(100) = 'FantasyScore';

	DECLARE @intStartweek INT = CONVERT(INT, @startweek), @intEndweek INT = CONVERT(INT, @endweek);
	DECLARE @startDate DATETIME, @endDate DATETIME;

	IF (@intStartweek > @intEndweek)
	BEGIN
		RETURN;
	END

	--Check if difference is equal to 0
	IF (@intEndweek - @intStartweek = 0 )
	BEGIN
		SET @intStartweek = @intEndweek;
	END
	
	DECLARE @teams TABLE (team_key VARCHAR(100), away_team_key VARCHAR(100), event_key VARCHAR(100), week INT);

	WHILE (@intStartweek <= @intEndweek)
	BEGIN

		SELECT @startDate = MIN(start_date_time_EST), @endDate = MAX(start_date_time_EST)
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = @subSeasonKey AND [week] = @intStartweek;

		IF (LOWER(@range) = 'all')
		BEGIN
			no_op:
		END
		ELSE
		BEGIN
			IF (LOWER(@range) = 'sun')
			BEGIN
				SET @startDate = CONVERT(DATE, @startDate);
				SET @startDate = DATEADD(DAY, 8 - DATEPART(weekday, @startDate), @startDate);
				SET @endDate = DATEADD(DAY, 1, @startDate);
			END
			ELSE IF (LOWER(@range) = 'sun-mon')
			BEGIN
				SET @startDate = CONVERT(DATE, @startDate);
				SET @startDate = DATEADD(DAY, 8 - DATEPART(weekday, @startDate), @startDate);--Get next sunday 12:00 AM
			END
			ELSE IF (LOWER(@range) = 'thu-sun')
			BEGIN
				SET @startDate = CONVERT(DATE, @startDate);
				SET @startDate = DATEADD(DAY, 5 - DATEPART(weekday, @startDate), @startDate);--Get current thursday 12:00 AM
				SET @endDate = CONVERT(DATE, @endDate);
			END
			ELSE IF (LOWER(@range) = 'mon')
			BEGIN
				SET @startDate = CONVERT(DATE, @endDate);
			END
		END

		INSERT INTO @teams
		SELECT home_team_key, away_team_key, event_key, [week]
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = @subSeasonKey AND [week] = @intStartweek AND start_date_time_EST >= @startDate AND start_date_time_EST <= @endDate
		UNION
		SELECT away_team_key, home_team_key, event_key, [week]
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = @subSeasonKey AND [week] = @intStartweek AND start_date_time_EST >= @startDate AND start_date_time_EST <= @endDate;

		SET @intStartweek += 1;
	END

	--Temp table for getting data
	DECLARE @info TABLE (
		team_key				VARCHAR(50), 
		team					VARCHAR(10),
		week					INT,
		--QB
		passes_yards 			VARCHAR(100),
		passes_touchdowns	 	VARCHAR(100),
		passes_interceptions 	VARCHAR(100),

		--RB
		rushes_touchdowns 		VARCHAR(100),
		rushes_yards 			VARCHAR(100),

		--WR
		receptions_total 		VARCHAR(100),
		receptions_touchdowns 	VARCHAR(100),
		receptions_yards 		VARCHAR(100),

		--TE
		extra_points_made 		VARCHAR(100),
		field_goals_made 		VARCHAR(100),

		QB_points				DECIMAL(15,2),
		RB_points				DECIMAL(15,2),
		WR_points				DECIMAL(15,2),
		TE_points				DECIMAL(15,2),

		QB_rank					INT,
		RB_rank					INT,
		WR_rank					INT,
		TE_rank					INT
	);

	--Get the teams
	INSERT INTO @info (team_key,team,week,passes_yards,passes_interceptions,rushes_yards)
	SELECT teams.team_key, teams.team_abbreviation, teams1.week, passyd.value, passint.value, rushyd.value
	  FROM SportsDB.dbo.SMG_Teams teams
	 INNER JOIN @teams teams1
    	ON teams.season_key = @seasonKey
   	   AND teams.league_key = @leagueKey
	   AND teams1.team_key = teams.team_key
     INNER JOIN SportsEditDB.dbo.SMG_Events_football passyd
		ON passyd.league_key = @leagueKey
	   AND passyd.season_key = @seasonKey 
	   AND passyd.sub_season_type = 'season-regular' 
	   AND passyd.team_key = teams1.away_team_key
	   AND passyd.event_key = teams1.event_key
	   AND passyd.player_key = 'team'
	   AND passyd.[column] = 'passes-yards-gross'
     INNER JOIN SportsEditDB.dbo.SMG_Events_football passint
		ON passint.league_key = @leagueKey
	   AND passint.season_key = @seasonKey 
	   AND passint.sub_season_type = 'season-regular' 
	   AND passint.team_key = teams1.away_team_key
	   AND passint.event_key = teams1.event_key
	   AND passint.player_key = 'team'
	   AND passint.[column] = 'passes-interceptions'
     INNER JOIN SportsEditDB.dbo.SMG_Events_football rushyd
		ON rushyd.league_key = @leagueKey
	   AND rushyd.season_key = @seasonKey 
	   AND rushyd.sub_season_type = 'season-regular' 
	   AND rushyd.team_key = teams1.away_team_key
	   AND rushyd.event_key = teams1.event_key
	   AND rushyd.player_key = 'team'
	   AND rushyd.[column] = 'rushes-yards';
	   
	UPDATE temp
	   SET temp.passes_touchdowns = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'passes-touchdowns'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.rushes_touchdowns = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'rushes-touchdowns'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.receptions_total = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'receptions-total'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.receptions_touchdowns = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'receptions-touchdowns'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.receptions_yards = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'receptions-yards'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.extra_points_made = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'extra-points-made'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	UPDATE temp
	   SET temp.field_goals_made = stats.value
	  FROM @info temp
   	 INNER JOIN (SELECT teams.team_key, SUM(CONVERT(DECIMAL(15,2), value)) AS value
		 		   FROM @teams teams
	 			  INNER JOIN SportsEditDB.dbo.SMG_Events_football stats
   	    		  	 ON stats.league_key = @leagueKey
	   			  	AND stats.season_key = @seasonKey 
	   			 	AND stats.sub_season_type = 'season-regular' 
	   			 	AND stats.team_key = teams.away_team_key
	   			 	AND stats.event_key = teams.event_key
					AND stats.player_key <> 'team'
	   			 	AND stats.[column] = 'field-goals-made'
				  GROUP BY teams.team_key
			    ) stats
    	ON temp.team_key = stats.team_key

	--Update Fantasy Points for QB, RB, WR, TE
	UPDATE temp
	   SET temp.QB_points = CONVERT(DECIMAL(15,2),(temp.passes_yards * scoring.yards_pass) + (temp.passes_touchdowns * scoring.td_pass) + (temp.passes_interceptions * scoring.interception_pass)),
			temp.RB_points = CONVERT(DECIMAL(15,2),(temp.rushes_touchdowns * scoring.td_run) + (temp.rushes_yards * scoring.yards_run)),
			temp.WR_points = CONVERT(DECIMAL(15,2),(temp.receptions_total * scoring.receptions) + (temp.receptions_touchdowns * scoring.td_receive) + (temp.receptions_yards * scoring.yards_receive)),
			temp.TE_points = CONVERT(DECIMAL(15,2),(temp.extra_points_made * scoring.pat_kick) + (temp.field_goals_made * scoring.fieldgoal_kick)) 
	  FROM @info temp
   	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_Scoring scoring
    	ON scoring.name = @editor;

	--SELECT (SELECT * FROM @info ORDER BY TE_RANK FOR XML RAW('team'), TYPE) FOR XML PATH(''), ROOT('fantasy');
	IF (LOWER(@position) = 'qb')
	BEGIN
		SELECT
		(
			SELECT team_key, team, QB_points, ROW_NUMBER() OVER(ORDER BY QB_points DESC, team ASC) AS QB_rank 
			  FROM	(
					SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(QB_points)) as QB_points
					  FROM @info 
					  GROUP BY team_key, team
					) info
			 ORDER BY QB_rank, team
			   FOR XML RAW('teams'), TYPE
		)
		FOR XML PATH(''), ROOT('fantasy');
	END
	ELSE IF (LOWER(@position) = 'rb')
	BEGIN
		SELECT
		(
			SELECT team_key, team, RB_points, ROW_NUMBER() OVER(ORDER BY RB_points DESC, team ASC) AS RB_rank 
			  FROM	(
					SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(RB_points)) as RB_points
					  FROM @info 
					  GROUP BY team_key, team
					) info
			 ORDER BY RB_rank, team
			   FOR XML RAW('teams'), TYPE
		)
		FOR XML PATH(''), ROOT('fantasy');
	END
	ELSE IF (LOWER(@position) = 'wr')
	BEGIN
		SELECT
		(
			SELECT team_key, team, WR_points, ROW_NUMBER() OVER(ORDER BY WR_points DESC, team ASC) AS WR_rank 
			  FROM	(
					SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(WR_points)) as WR_points
					  FROM @info 
					  GROUP BY team_key, team
					) info
			 ORDER BY WR_rank, team
			   FOR XML RAW('teams'), TYPE
		)
		FOR XML PATH(''), ROOT('fantasy');
	END
	ELSE IF (LOWER(@position) = 'te')
	BEGIN
		SELECT
		(
			SELECT team_key, team, TE_points, ROW_NUMBER() OVER(ORDER BY TE_points DESC, team ASC) AS TE_rank 
			  FROM	(
					SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(TE_points)) as TE_points
					  FROM @info 
					  GROUP BY team_key, team
					) info
			 ORDER BY TE_rank, team
			   FOR XML RAW('teams'), TYPE
		)
		FOR XML PATH(''), ROOT('fantasy');
	END
	ELSE
	BEGIN
		SELECT
		(
			SELECT QB_info.team_key, QB_info.team, QB_points, QB_rank, RB_points, RB_rank, WR_points, WR_rank, TE_points, TE_rank
			  FROM (
					SELECT team_key, team, QB_points, ROW_NUMBER() OVER(ORDER BY QB_points DESC, team ASC) AS QB_rank 
					  FROM	(
							SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(QB_points)) as QB_points
							  FROM @info 
							  GROUP BY team_key, team
							) info
					) QB_info
			INNER JOIN (
					SELECT team_key, team, RB_points, ROW_NUMBER() OVER(ORDER BY RB_points DESC, team ASC) AS RB_rank 
					  FROM	(
							SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(RB_points)) as RB_points
							  FROM @info 
							  GROUP BY team_key, team
							) info
					) RB_info
				ON QB_info.team_key = RB_info.team_key
			INNER JOIN (
					SELECT team_key, team, WR_points, ROW_NUMBER() OVER(ORDER BY WR_points DESC, team ASC) AS WR_rank 
					  FROM	(
							SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(WR_points)) as WR_points
							  FROM @info 
							  GROUP BY team_key, team
							) info
					) WR_info
				ON QB_info.team_key = WR_info.team_key
			INNER JOIN (
					SELECT team_key, team, TE_points, ROW_NUMBER() OVER(ORDER BY TE_points DESC, team ASC) AS TE_rank 
					  FROM	(
							SELECT team_key, team, CONVERT(DECIMAL(15,2), AVG(TE_points)) as TE_points
							  FROM @info 
							  GROUP BY team_key, team
							) info
					) TE_info
				ON QB_info.team_key = TE_info.team_key
			 ORDER BY QB_rank, team
			   FOR XML RAW('teams'), TYPE
		)
		FOR XML PATH(''), ROOT('fantasy');
	END
END


GO
