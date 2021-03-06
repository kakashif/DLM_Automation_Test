USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLFantasyRankings_New_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNFLFantasyRankings_New_XML] 
	@seasonKey VARCHAR(10) = '2014',
	@subseasonKey VARCHAR(100) = 'season-regular',
	@week VARCHAR(100) = '1',
    @range VARCHAR(100) = 'all',
    @position VARCHAR(10) = 'all',
    @editors VARCHAR(500) = 'all',
    @scoringSystem VARCHAR(100) = 'FantasyScore'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 09/10/2014
-- Description: Get NFL Fantasy Ranking Data
-- Update:		09/18/2014 - pkamat: Fix to get json array for only 1 editor
-- 				09/19/2014 - pkamat: Get rankings of players for each editor
-- 				09/23/2014 - pkamat: Replace FB with RB, add positional rank
-- 				09/26/2014 - pkamat: Added regular position column as well, include players not deleted, format salary as xx,xxx
-- 				09/30/2014 - pkamat: Added scoring system as input param
-- 				10/03/2014 - pkamat: Remove inactive players, rank by status; avg points desc; salary desc; name asc
-- 				10/06/2014 - pkamat: Added injury classification
-- 				10/09/2014 - pkamat: Return if no editors are present if scoring system is not FantasyScore, fix rank calculation in editor subquery for xml,
--									 Update injury abbr of all players 
-- 				10/13/2014 - pkamat: Get editors including numberfire if scoring system is not FantasyScore.
-- 				10/15/2014 - pkamat: Performance tuning, removed ranking by editor in xml query
-- 				10/17/2014 - pkamat: Removed update for team adp and salary
-- 				10/20/2014 - pkamat: Added flex in position
-- 				10/24/2014 - pkamat: Shorten the first name to initial for players, last name for teams
-- 				10/27/2014 - pkamat: Add opponent for each player
-- 				10/31/2014 - pkamat: Add slug for each player and team,
--									 Removed dupes for teams
-- 				11/06/2014 - pkamat: Handle kicker in positions
-- 				11/18/2014 - pkamat: Handle post season weeks
-- 				11/20/2014 - pkamat: Added editor list as json, add editor name as xml node name
-- 				11/21/2014 - pkamat: Added editor name as xml node, points as node value
-- 				11/24/2014 - pkamat: Added player last name
--              12/31/2014 - John Lin - move editor_week to top
-- 				01/12/2015 - pkamat: Changed data type of @week to VARCHAR(100) for championship week
-- 				01/26/2015 - pkamat: Added superbowl week for post season
--              01/29/2015 - John Lin - rename championship to conference
--              06/02/2015 - pkamat: Added pre-season week 0 logic
-- 		   		06/08/2015 - pkamat: Remove " from player slug
-- 		   		06/09/2015 - pkamat: Changed calculation of average points, removed prev week points and prev week rank
-- 		   		06/10/2015 - pkamat: Added bye week for pre-season
-- 		   		06/28/2015 - pkamat: Added player key and team key as PRIMARY KEYS
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

	DECLARE @positions TABLE (name VARCHAR(10), display VARCHAR(10));
	IF (LOWER(@position) = 'all')
	BEGIN
		INSERT INTO @positions VALUES('d','DST'),('fb','RB'),('fb/rb','RB'),('kr/pr','KR'),('pk','K'),('k','K'),('qb','QB'),('rb','RB'),('te','TE'),('te/fb','TE'),('wr','WR'),('wr/kr','WR'),('wr/pr','WR'),('wr/rb','WR');
	END
	ELSE IF (LOWER(@position) = 'flex')
	BEGIN
		INSERT INTO @positions VALUES('fb','RB'),('fb/rb','RB'),('rb','RB'),('te','TE'),('te/fb','TE'),('wr','WR'),('wr/kr','WR'),('wr/pr','WR'),('wr/rb','WR');
	END
	ELSE IF (LOWER(@position) = 'fb')
	BEGIN
		INSERT INTO @positions VALUES('fb',UPPER(@position)),('fb/rb',UPPER(@position)),('te/fb',UPPER(@position));
	END
	ELSE IF (LOWER(@position) = 'kr')
	BEGIN
		INSERT INTO @positions VALUES('kr/pr',UPPER(@position)),('wr/kr',UPPER(@position));
	END
	ELSE IF (LOWER(@position) = 'pr')
	BEGIN
		INSERT INTO @positions VALUES('kr/pr',UPPER(@position)),('wr/pr',UPPER(@position));
	END
	ELSE IF (LOWER(@position) = 'rb')
	BEGIN
		INSERT INTO @positions VALUES('fb',UPPER(@position)),('fb/rb',UPPER(@position)),('rb',UPPER(@position)),('wr/rb',UPPER(@position));
	END
	ELSE IF (LOWER(@position) = 'te')
	BEGIN
		INSERT INTO @positions VALUES('te',UPPER(@position)),('te/fb',UPPER(@position));
	END
	ELSE IF (LOWER(@position) = 'pk' OR LOWER(@position) = 'k')
	BEGIN
		INSERT INTO @positions VALUES('pk','K'),('k','K');
	END
	ELSE IF (LOWER(@position) = 'd' OR LOWER(@position) = 'dst')
	BEGIN
		INSERT INTO @positions VALUES('d','DST');
	END
	ELSE IF (LOWER(@position) = 'wr')
	BEGIN
		INSERT INTO @positions VALUES('wr',UPPER(@position)),('wr/kr',UPPER(@position)),('wr/pr',UPPER(@position)),('wr/rb',UPPER(@position));
	END
	ELSE
	BEGIN
		INSERT INTO @positions VALUES (@position,UPPER(@position));
	END

	DECLARE @editor TABLE (name VARCHAR(500));
	DECLARE @editor_week VARCHAR(10), @schedule_week VARCHAR(10);
	
	IF (LOWER(@week) = 'super-bowl')
	BEGIN
		SELECT @editor_week = '21';
	END
	ELSE IF (LOWER(@week) = 'conference')
	BEGIN
		SELECT @editor_week = '20';
	END
	ELSE IF (LOWER(@week) = 'divisional')
	BEGIN
		SELECT @editor_week = '19';
	END
	ELSE IF (LOWER(@week) = 'wild-card')
	BEGIN
		SELECT @editor_week = '18';
	END
	ELSE
	BEGIN
		SELECT @editor_week = @week;
	END

	SELECT @schedule_week = CASE @week WHEN '0' THEN '1' ELSE @WEEK END;

	IF (LOWER(@editors) = 'all')
	BEGIN
		SET @editors = NULL;

		INSERT INTO @editor 
		SELECT DISTINCT editor
		  FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections projections
		 WHERE season_key = @seasonKey
		   AND sub_season_key = @subseasonKey
		   AND week = @editor_week
		   AND LOWER(scoring_system) = LOWER(@scoringSystem);
	END
	ELSE
	BEGIN
        WHILE (CHARINDEX(',', @editors) > 0 ) 
        BEGIN  
			INSERT INTO @editor SELECT LTRIM(RTRIM(SUBSTRING(@editors, 1, CHARINDEX(',', @editors) - 1)));
            SET @editors = SUBSTRING(@editors, CHARINDEX(',', @editors) + 1, LEN(@editors));
        END 
		INSERT INTO @editor SELECT LTRIM(RTRIM(@editors));
	END

	DECLARE @startDate DATETIME, @endDate DATETIME;
	SELECT @startDate = MIN(start_date_time_EST), @endDate = MAX(start_date_time_EST)
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type IN ('season-regular', 'post-season') 
	   AND [week] = @schedule_week;

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

	--Check whether editors are present for any Scoring System 
	DECLARE @editorCount INT = 0;

	SELECT @editorCount = COUNT(DISTINCT editor)
	  FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections projections
	 WHERE projections.season_key = @seasonKey
	   AND projections.sub_season_key = @subseasonKey
	   AND projections.week = @editor_week
	   AND LOWER(projections.position) IN (SELECT name from @positions)
	   AND LOWER(scoring_system) = LOWER(@scoringSystem);

	IF (@editorCount = 0)
	BEGIN
		RETURN
	END

	DECLARE @teams TABLE (team_key VARCHAR(100), opp VARCHAR(100));

	INSERT INTO @teams
	SELECT home_team_key, away_team_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type IN ('season-regular', 'post-season') 
	   AND [week] = @schedule_week AND start_date_time_EST >= @startDate AND start_date_time_EST <= @endDate
	UNION
	SELECT away_team_key, home_team_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type IN ('season-regular', 'post-season') 
	   AND [week] = @schedule_week AND start_date_time_EST >= @startDate AND start_date_time_EST <= @endDate;

	DECLARE @info TABLE (
		name			VARCHAR(200),
		last_name		VARCHAR(200),
		player_key		VARCHAR(50),
		player_slug		VARCHAR(200),
		team			VARCHAR(10),
		team_key		VARCHAR(50),
		opponent		VARCHAR(10),
		position		VARCHAR(10),
		position_reg	VARCHAR(10),
		status			VARCHAR(50),
		injury_abbr		VARCHAR(5) DEFAULT '',
		injury			VARCHAR(100) DEFAULT '',
		injury_details	VARCHAR(100) DEFAULT '',
		adp				VARCHAR(10),
		salary			VARCHAR(10),
		avg_points		DECIMAL(25,2),
		avg_points_prev DECIMAL(25,2),
		bye_week		INT,
		rank_pos		INT,
		rank			INT,
		rank_prev		INT,
		PRIMARY KEY (player_key, team_key)
	);

	--Calculate current and previous weeks in post season
    DECLARE @prev_week VARCHAR(10);
	IF (LOWER(@week) = 'super-bowl')
	BEGIN
		SELECT @prev_week = '20', @week = '21';
	END
	ELSE IF (LOWER(@week) = 'conference')
	BEGIN
		SELECT @prev_week = '19', @week = '20';
	END
	ELSE IF (LOWER(@week) = 'divisional')
	BEGIN
		SELECT @prev_week = '18', @week = '19';
	END
	ELSE IF (LOWER(@week) = 'wild-card')
	BEGIN
		SELECT @prev_week = '17', @week = '18';
	END
	ELSE
	BEGIN
		SELECT @prev_week = CAST(@week as INT) - 1;
	END

	--Get the players
	INSERT INTO @info (name,last_name,player_key,team,team_key,player_slug,position,position_reg,status)
	SELECT LEFT(players.first_name, 1) + '. ' + players.last_name, players.last_name, players.player_key, teams.team_abbreviation, teams.team_key, 
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(players.first_name + ' ' + players.last_name), '/', '-'), '''', ''), '"', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),
			(SELECT display from @positions WHERE name = LOWER(rosters.position_regular)), rosters.position_regular, rosters.phase_status
	  FROM dbo.SMG_Players players
	 INNER JOIN dbo.SMG_Teams teams
	    ON teams.season_key = @seasonKey
	   AND teams.league_key = @leagueKey
	 INNER JOIN @teams teams1
	    ON teams1.team_key = teams.team_key
	 INNER JOIN dbo.SMG_Rosters rosters
		ON rosters.team_key = teams.team_key
	   AND rosters.season_key = @seasonKey
	   AND rosters.player_key = players.player_key
	   AND rosters.phase_status NOT IN ('delete') --, 'inactive')
	   AND LOWER(rosters.position_regular) IN (SELECT name from @positions);

	--Get the defensive teams
	INSERT INTO @info (name,last_name,player_key,team,team_key,player_slug,position,position_reg, status)
	SELECT DISTINCT teams.team_last, teams.team_last, teams.team_key, teams.team_abbreviation, teams.team_key, 
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(teams.team_first + ' ' + teams.team_last), '/', '-'), '''', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),
			(SELECT display from @positions WHERE name = LOWER(projections.position)), projections.position, 'active'
	  FROM dbo.SMG_Teams teams
	 INNER JOIN @teams teams1
	    ON teams.season_key = @seasonKey
	   AND teams.league_key = @leagueKey
	   AND teams1.team_key = teams.team_key
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_NFL_Projections projections
	    ON projections.season_key = @seasonKey
	   AND projections.sub_season_key = @subseasonKey
	   AND projections.week = @week
	   AND projections.player_key = teams.team_key
	   AND LOWER(projections.position) IN (SELECT name from @positions)
	   AND LOWER(scoring_system) = LOWER(@scoringSystem)
	   --AND LOWER(editor) = 'numberfire';

	--Delete Players not having projections
	DELETE @info
	 WHERE player_key NOT IN (SELECT player_key 
								FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections projections
								WHERE projections.season_key = @seasonKey
							      AND projections.sub_season_key = @subseasonKey
							      AND projections.week = @week
								  AND LOWER(scoring_system) = LOWER(@scoringSystem));

	--Update opponent
	UPDATE temp
	   SET temp.opponent = teams.team_abbreviation
	  FROM @info temp
	 INNER JOIN @teams teams1
		ON temp.team_key = teams1.team_key
	 INNER JOIN dbo.SMG_Teams teams
		ON teams.season_key = @seasonKey
	   AND teams.league_key = @leagueKey
	   AND teams.team_key = teams1.opp;

	--Update bye week for 2015 in pre-season
	/*
		Byes by week
		Week 4
			Tennessee Titans, New England Patriots
		Week 5
			Carolina Panthers, Miami Dolphins, Minnesota Vikings, New York Jets
		Week 6
			Dallas Cowboys, Oakland Raiders, St. Louis Rams, Tampa Bay Buccaneers
		Week 7
			Chicago Bears, Cincinnati Bengals, Denver Broncos, Green Bay Packers
		Week 8
			Buffalo Bills, Jacksonville Jaguars, Philadelphia Eagles, Washington Redskins
		Week 9
			Arizona Cardinals, Baltimore Ravens, Detroit Lions, Houston Texans, Kansas City Chiefs, Seattle Seahawks
		Week 10
			Atlanta Falcons, Indianapolis Colts, San Diego Chargers, San Francisco 49ers
		Week 11
			Cleveland Browns, New Orleans Saints, New York Giants, Pittsburgh Steelers
	*/
	IF (@week = '0')
	BEGIN
		UPDATE @info
		   SET bye_week =  CASE WHEN team IN ('TEN', 'NE') THEN 4
								WHEN team IN ('CAR', 'MIA', 'MIN', 'NYJ') THEN 5
								WHEN team IN ('DAL', 'OAK', 'STL', 'TB') THEN 6
								WHEN team IN ('CHI', 'CIN', 'DEN', 'GB') THEN 7
								WHEN team IN ('BUF', 'JAC', 'PHI', 'WAS') THEN 8
								WHEN team IN ('ARI', 'BAL', 'DET', 'HOU', 'KC', 'SEA') THEN 9
								WHEN team IN ('ATL', 'IND', 'SD', 'SF') THEN 10
								WHEN team IN ('CLE', 'NO', 'NYG', 'PIT') THEN 11
							END;
		
	END
	
	--Update the average points of the players
	UPDATE temp
	   SET temp.avg_points = (SELECT SUM(points_calculated)/@editorCount AS avg_points 
				   FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections 
				  WHERE season_key = @seasonKey
					AND sub_season_key = @subseasonKey
				    AND week = @week
					AND (ISNULL(@editors, '1') = '1' OR editor IN (SELECT name FROM @editor))
					AND LOWER(scoring_system) = LOWER(@scoringSystem)
                    AND player_key = temp.player_key 
				  GROUP BY player_key)
	  FROM @info temp;

	--Update the previous week average points of the players
	/*UPDATE temp
	   SET temp.avg_points_prev = (SELECT SUM(points_calculated)/@editorCount AS avg_points 
				   FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections 
				  WHERE season_key = @seasonKey
					AND sub_season_key = @subseasonKey
				    AND week = @prev_week
					AND (ISNULL(@editors, '1') = '1' OR editor IN (SELECT name FROM @editor))
					AND LOWER(scoring_system) = LOWER(@scoringSystem)
                    AND player_key = temp.player_key 
				  GROUP BY player_key
				) 
	  FROM @info temp;*/

	--Update adp, salary for players
	UPDATE temp
	   SET temp.adp = fantasy.adp, temp.salary = fantasy.salary
	  FROM @info temp
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports_Mapping mapping
			ON temp.player_key = mapping.player_key
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
			ON fantasy.rtfs_id = mapping.rtfs_id
		   AND fantasy.league_key = @leagueKey
		   AND fantasy.season_key = @seasonKey
		   AND fantasy.sub_season_key = @subseasonKey
		   AND (ISNULL(@week, '#') = '#' OR fantasy.week = @week);

	--Update current rank
	UPDATE temp
	   SET temp.rank = ranks.rank
	  FROM @info temp
	 INNER JOIN (SELECT player_key, ROW_NUMBER() OVER(ORDER BY CASE status WHEN 'suspended' THEN 1 ELSE 0 END, avg_points DESC, CONVERT(DECIMAL, salary) DESC, name ASC) AS rank 
				   FROM @info 
				) ranks
		ON temp.player_key = ranks.player_key;

	--Update previous rank
	/*UPDATE temp
	   SET temp.rank_prev = ranks.rank
	  FROM @info temp
	 INNER JOIN (SELECT player_key, ROW_NUMBER() OVER(ORDER BY CASE status WHEN 'suspended' THEN 1 ELSE 0 END, avg_points_prev DESC, CONVERT(DECIMAL, salary) DESC, name ASC) AS rank 
				   FROM @info 
				) ranks
		ON temp.player_key = ranks.player_key;*/

	--Update positional rank
	UPDATE temp
	   SET temp.rank_pos = ranks.rank
	  FROM @info temp
	 INNER JOIN (SELECT player_key, ROW_NUMBER() OVER(PARTITION BY positions.display ORDER BY info.avg_points DESC, CONVERT(DECIMAL, salary) DESC, info.name ASC) AS rank 
				   FROM @info info
				  INNER JOIN @positions positions
					 ON info.position = positions.name

				) ranks
		ON temp.player_key = ranks.player_key;


	--Update the injury status of the players
	DECLARE @injuries TABLE (name VARCHAR(100), abbr VARCHAR(10));
	INSERT INTO @injuries VALUES('probable','P'),('questionable','Q'),('doubtful','D'),('out','O'),('injured-reserve','IR'),('physically-unable','PUP');

	UPDATE temp
	   SET temp.status = CASE temp.status WHEN 'active' THEN 'injured' ELSE temp.status END, temp.injury = injuries.injury_class, temp.injury_details = injuries.injury_details, temp.injury_abbr = (SELECT abbr FROM @injuries WHERE name = injuries.injury_class)
	  FROM @info temp
	 INNER JOIN dbo.SMG_Injuries injuries
		ON temp.player_key = injuries.player_key;

	--Update the injury abbr of the suspended players
	UPDATE @info
	   SET injury_abbr = 'SSPD'
	 WHERE status IN ('suspended') ;

	--Update salary to xx,xxxx
	UPDATE @info
	   SET salary = PARSENAME(CONVERT(VARCHAR,CAST(salary AS MONEY),1),2);

	--Fill all null values
	UPDATE temp
	   SET temp.avg_points = ISNULL(temp.avg_points, 0.0), --temp.avg_points_prev = ISNULL(temp.avg_points_prev, 0.0), 
			temp.adp = ISNULL(temp.adp, '0'), temp.salary = ISNULL(temp.salary, '0')
	  FROM @info temp;

	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
	 SELECT CONVERT(XML, '<proc>dbo.HUB_GetNFLFantasyRankings_New_XML</proc>' )
	),
	(SELECT
		(SELECT CONVERT(XML, '<' + name + '>1</' + name + '>')
		   FROM @editor temp
		  ORDER BY CASE name WHEN 'numberfire' THEN 1 ELSE 2 END, name
			FOR XML raw, type
		).query('row/*')
		FOR XML raw('editors'), type
	),
	(
        SELECT fantasy.player_key, fantasy.name, fantasy.last_name, fantasy.player_slug, fantasy.position, fantasy.position_reg, fantasy.team, fantasy.opponent, fantasy.avg_points, fantasy.avg_points_prev as avg_points_lst_wk,
				fantasy.adp, fantasy.salary, fantasy.status, fantasy.injury, fantasy.injury_abbr, fantasy.injury_details,
				fantasy.rank, fantasy.rank_pos, fantasy.bye_week, --fantasy.rank_prev AS rank_lst_wk, (fantasy.rank_prev - fantasy.rank) as rank_diff, 
				(CONVERT(DECIMAL, fantasy.adp) - fantasy.rank) AS v_adp,
				(SELECT
					(SELECT CONVERT(XML, '<' + editor + '>' + CONVERT(VARCHAR, points) + '</' + editor + '>') 
					   FROM (SELECT name AS editor, ISNULL(points_calculated, 0) AS points
							   FROM @editor temp
							   LEFT OUTER JOIN SportsEditDB.dbo.SMG_Fantasy_NFL_Projections projections
								 ON temp.name = projections.editor
								AND season_key = @seasonKey
								AND sub_season_key = @subseasonKey
								AND week = @week
								AND LOWER(scoring_system) = LOWER(@scoringSystem)
								AND projections.player_key = fantasy.player_key
							) as editor_points
					  ORDER BY CASE editor WHEN 'numberfire' THEN 1 ELSE 2 END, editor
						FOR XML RAW, TYPE 
					).query('row/*')
					FOR XML RAW('editors'), TYPE
				)
		  FROM @info fantasy
		 ORDER BY fantasy.rank, fantasy.name
           FOR XML RAW('players'), TYPE
    )
    FOR XML PATH(''), ROOT('fantasy')

END

GO
