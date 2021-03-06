USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLFantasyDepth_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNFLFantasyDepth_XML] 
	@seasonKey VARCHAR(10) = '2014',
	@subseasonKey VARCHAR(100) = 'season-regular',
    @team VARCHAR(10) = 'all'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 08/27/2014
-- Description: Get NFL Fantasy Depths Data 
-- Update:		09/22/2014 - pkamat: Filter by selected positions QB, RB, WR, TE only
--				09/23/2014 - pkamat: Format salary as xx,xxx
--				09/25/2014 - pkamat: Group depth by positions
--				09/26/2014 - pkamat: Added average points ytd
--				10/03/2014 - pkamat: Increased average points data type to DECIMAL(15,2), Remove inactive players, changed query to join rosters for correct positions, merged RB1 and RB2 positions into RB, included WR3 position
--				10/07/2014 - pkamat: Added injury classification
-- 				10/09/2014 - pkamat: Update injury abbr of all players
-- 				10/30/2014 - pkamat: Shorten the first name to initial for players
-- 				10/31/2014 - pkamat: Add slug for each player and team
-- 				11/11/2014 - pkamat: Get actual ytd points
-- 				11/18/2014 - pkamat: Handle post season weeks
-- 				01/26/2015 - pkamat: Added superbowl week for post season
--              01/29/2015 - John Lin - rename championship to conference
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

	IF (LOWER(@team) = 'all')
	BEGIN
		SET @team = NULL;
	END

	DECLARE @positions TABLE (name VARCHAR(10), display VARCHAR(10), display_name VARCHAR(100), ord INT);
	INSERT INTO @positions VALUES ('qb','QB','Quarterback',1),('rb','RB','Running Back',2),('fb','RB','Running Back',2),('rb1','RB','Running Back',4),('rb2','RB','Running Back',4),
		('wr1','WR1','Wide Receiver 1',6),('wr2','WR2','Wide Receiver 2',7),('wr3','WR3','Wide Receiver 3',8),('te','TE','Tight End',9),('te1','TE','Tight End',9),('te2','TE','Tight End',9),('k','K','Kicker',10);

	DECLARE @info TABLE (
		player_key		VARCHAR(100),
		name			VARCHAR(200),
		player_slug		VARCHAR(200),
		team			VARCHAR(10),
		team_key		VARCHAR(100),
		display_name	VARCHAR(100),
		depth_name		VARCHAR(100),
		depth_position	INT,
		ord				INT,
		college			VARCHAR(100),
		height			VARCHAR(100),
		weight			VARCHAR(100),
		date_of_birth	DATE,
		age				INT,
		salary			VARCHAR(100),
		points			DECIMAL(15,2),
		avg_points_ytd	DECIMAL(15,2),
		status			VARCHAR(50),
		injury_abbr		VARCHAR(5) DEFAULT '',
		injury			VARCHAR(100) DEFAULT '',
		injury_details	VARCHAR(100) DEFAULT ''
	);

	DECLARE @week VARCHAR(100), @defaultSubseasonKey VARCHAR(100);

	SELECT @week = week, @defaultSubseasonKey = sub_season_type
	  FROM dbo.SMG_Default_Dates WHERE league_key = @leagueName AND season_key = @seasonKey and page = 'schedules';

	--Check post season weeks
	IF (LOWER(@week) = 'super-bowl')
	BEGIN
		SELECT @week = '21';
	END
	ELSE IF (LOWER(@week) = 'conference')
	BEGIN
		SELECT @week = '20';
	END
	ELSE IF (LOWER(@week) = 'divisional')
	BEGIN
		SELECT @week = '19';
	END
	ELSE IF (LOWER(@week) = 'wild-card')
	BEGIN
		SELECT @week = '18';
	END

	INSERT INTO @info (player_key,name,team,team_key,player_slug,display_name,depth_name,depth_position,ord,college,status,height,weight,date_of_birth,age,salary,points,avg_points_ytd)
	SELECT DISTINCT players.player_key, LEFT(players.first_name, 1) + '. ' + players.last_name, teams.team_abbreviation, teams.team_key, 
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(players.first_name + ' ' + players.last_name), '/', '-'), '''', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),			
			positions.display, depths.depth_name, depths.depth_position, positions.ord, players.college_name,rosters.phase_status,
			rosters.height, rosters.weight, players.date_of_birth, DATEDIFF(YEAR, players.date_of_birth, CONVERT(DATE, GETDATE())),
			ISNULL((SELECT PARSENAME(CONVERT(VARCHAR,CAST(fantasy.salary AS MONEY),1),2)
					  FROM SportsEditDB.dbo.SMG_Fantasy_RTSports_Mapping mapping
					 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
						ON fantasy.rtfs_id = mapping.rtfs_id
					   AND fantasy.league_key = @leagueKey
					   AND fantasy.season_key = @seasonKey
					   AND fantasy.sub_season_key = 'season-regular'
					   AND fantasy.week = @week
					 WHERE mapping.player_key = players.player_key
			), '0'),
			ISNULL(( SELECT CONVERT(DECIMAL(15,2), AVG(points_calculated))
					   FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Projections 
					  WHERE season_key = @seasonKey
						AND sub_season_key = 'season-regular'
						AND week = @week
						AND player_key = players.player_key
			), '0.0'),
			ISNULL(( SELECT points
					   FROM SportsEditDB.dbo.SMG_Fantasy_NFL_Points 
					  WHERE season_key = @seasonKey
						AND player_key = players.player_key
			), '0.0')
	  FROM dbo.SMG_Players players
	 INNER JOIN dbo.SMG_Team_Depths depths
		ON players.player_key = depths.player_key
	 INNER JOIN @positions positions
		ON LOWER(depths.depth_name) = positions.name
	 INNER JOIN dbo.SMG_Rosters rosters
		ON rosters.player_key = players.player_key
	   AND rosters.season_key = @seasonKey
	   AND rosters.phase_status NOT IN ('delete', 'inactive')
	 INNER JOIN dbo.SMG_Teams teams
		ON teams.season_key = @seasonKey  
	   AND teams.league_key = @leagueKey  
	   AND teams.team_key = rosters.team_key
	 WHERE depths.league_key = @leagueKey
	   AND depths.season_key = @seasonKey
	   AND depths.sub_season_type IN ('season-regular', 'post-season') 
	   AND (ISNULL(@team, '1') = '1' OR LOWER(teams.team_abbreviation) = LOWER(@team));

	UPDATE @info SET ord = 3 WHERE depth_name = 'fb';

	--Update the injury status of the players
	DECLARE @injuries TABLE (name VARCHAR(100), abbr VARCHAR(10));
	INSERT INTO @injuries VALUES('probable','P'),('questionable','Q'),('doubtful','D'),('out','O'),('injured-reserve','IR'),('physically-unable','PUP');

	UPDATE temp
	   SET temp.status = CASE temp.status WHEN 'active' THEN 'injured' ELSE temp.status END, temp.injury = injuries.injury_class, temp.injury_details = injuries.injury_details, temp.injury_abbr = (SELECT abbr FROM @injuries WHERE name = injuries.injury_class)
	  FROM @info temp
	 INNER JOIN dbo.SMG_Injuries injuries
		ON temp.player_key = injuries.player_key;

	--Update the injury status of the suspended players
	UPDATE @info
	   SET injury_abbr = 'SSPD'
	 WHERE status IN ('suspended') ;

	--Delete positions not having any players
	DELETE FROM @positions WHERE name NOT IN (SELECT DISTINCT depth_name from @info);

	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json) 
	SELECT
	(
		SELECT display as position, display_name as position_name,
        (SELECT 'true' AS 'json:Array', player_key, name, player_slug, team, team_key, depth_name, depth_position, college, height, weight, date_of_birth, age, salary, points as projected_points, avg_points_ytd, status, injury, injury_abbr, injury_details
		  FROM @info
		 WHERE LOWER(display_name) = positions.display 
		 ORDER BY ord, depth_name, depth_position, points DESC
           FOR XML RAW('players'), TYPE
		)
		FROM (SELECT DISTINCT display, display_name, ord FROM @positions) positions
	   ORDER BY ord
		 FOR XML RAW('depths'), TYPE
    )
    FOR XML PATH(''), ROOT('fantasy')
    

END

GO
