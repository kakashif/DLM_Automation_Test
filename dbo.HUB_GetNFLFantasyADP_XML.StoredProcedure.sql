USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLFantasyADP_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNFLFantasyADP_XML] 
	@seasonKey VARCHAR(10) = '2014',
	@subseasonKey VARCHAR(100) = 'season-regular',
	@week VARCHAR(100) = '1',
    @position VARCHAR(10) = 'all'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 08/06/2014
-- Description: Get NFL Fantasy Data from RTSports
-- Update:		09/18/2014 - pkamat: Changed order to include ADP, ADP last week and total points
--				09/26/2014 - pkamat: Include defensive teams, change position to DST 
--				10/01/2014 - pkamat: Added rank, Increased adp data type to DECIMAL(15,2)
--				10/07/2014 - pkamat: Added injury classification, format salary as xx,xxx
-- 				10/09/2014 - pkamat: Update injury abbr of all players
-- 				10/31/2014 - pkamat: Shorten the first name to initial for players, last name for teams
-- 									 Add slug for each player and team
-- 				11/12/2014 - pkamat: Added flex in position,
--									removed extra columns
-- 				11/18/2014 - pkamat: Handle post season weeks
-- 				12/05/2014 - pkamat: Update team from SMG_Teams
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
		SET @subseasonKey = 'pre-season';
	END

	--Get default subseason key
	IF (@subseasonKey = 'pre-season')
	BEGIN
		SET @week = NULL;
	END

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

	DECLARE @positions TABLE (name VARCHAR(10));
	IF (LOWER(@position) = 'all')
	BEGIN
		SET @position = NULL;
	END
	ELSE IF (LOWER(@position) = 'flex')
	BEGIN
		INSERT INTO @positions VALUES('rb'),('te'),('wr');
	END
	ELSE IF (LOWER(@position) = 'dst')
	BEGIN
		SET @position = 'def';
		INSERT INTO @positions VALUES(@position);
	END
	ELSE
	BEGIN
		INSERT INTO @positions VALUES(LOWER(@position));
	END

	DECLARE @info TABLE (
		player_key			VARCHAR(100),
		rtfs_id				INT,
		stats_id    		INT,
		name				VARCHAR(200),
		player_slug			VARCHAR(200),
		position			VARCHAR(10),
		team				VARCHAR(10),
		week				VARCHAR(5),
		adp					VARCHAR(10),
		adp_ytd				VARCHAR(10),
		adp_lst_30			VARCHAR(10),
		adp_lst_wk 			VARCHAR(10),
		tot_pts_ytd			VARCHAR(10),
		tot_pts_lst_30		VARCHAR(10),
		tot_pts_lst_wk 		VARCHAR(10),
		avg_pts_ytd			VARCHAR(10),
		avg_pts_lst_30		VARCHAR(10),
		avg_pts_lst_wk 		VARCHAR(10),
		fnt_lineup			VARCHAR(10),
		fnt_lineup_ytd		VARCHAR(10),
		fnt_lineup_lst_30	VARCHAR(10),
		fnt_lineup_lst_wk 	VARCHAR(10),
		pct_lineup			VARCHAR(10),
		pct_lineup_ytd		VARCHAR(10),
		pct_lineup_lst_30	VARCHAR(10),
		pct_lineup_lst_wk 	VARCHAR(10),
		salary				VARCHAR(10),
		salary_ytd			VARCHAR(10),
		salary_lst_30		VARCHAR(10),
		salary_lst_wk 		VARCHAR(10),
		rank				INT,
		status				VARCHAR(50) DEFAULT 'active',
		injury_abbr			VARCHAR(5) DEFAULT '',
		injury				VARCHAR(100) DEFAULT '',
		injury_details		VARCHAR(100) DEFAULT ''
	);

	INSERT INTO @info (player_key,rtfs_id,stats_id,name,position,player_slug,team,status,week,adp,adp_ytd,adp_lst_30,adp_lst_wk,tot_pts_ytd,tot_pts_lst_30,tot_pts_lst_wk,avg_pts_ytd,avg_pts_lst_30,avg_pts_lst_wk,fnt_lineup,
		fnt_lineup_ytd,fnt_lineup_lst_30,fnt_lineup_lst_wk,pct_lineup,pct_lineup_ytd,pct_lineup_lst_30,pct_lineup_lst_wk,salary,salary_ytd,salary_lst_30,salary_lst_wk)
	SELECT mapping.player_key, fantasy.rtfs_id, stats_id, LEFT(players.first_name, 1) + '. ' + players.last_name as name, position, 
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(players.first_name + ' ' + players.last_name), '/', '-'), '''', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),
			teams.team_abbreviation, rosters.phase_status, fantasy.week, adp, adp_ytd, adp_lst_30, adp_lst_wk,
			tot_pts_ytd, tot_pts_lst_30, tot_pts_lst_wk, avg_pts_ytd, avg_pts_lst_30, avg_pts_lst_wk, 
			fnt_lineup, fnt_lineup_ytd, fnt_lineup_lst_30, fnt_lineup_lst_wk, pct_lineup, pct_lineup_ytd, pct_lineup_lst_30, pct_lineup_lst_wk, salary, salary_ytd, salary_lst_30, salary_lst_wk
	  FROM SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports_Mapping mapping
		ON fantasy.rtfs_id = mapping.rtfs_id
	 INNER JOIN dbo.SMG_Players players
		ON players.player_key = mapping.player_key
	 INNER JOIN dbo.SMG_Teams teams
	    ON teams.season_key = @seasonKey
	   AND teams.league_key = @leagueKey
	 INNER JOIN dbo.SMG_Rosters rosters
		ON rosters.team_key = teams.team_key
	   AND rosters.phase_status NOT IN ('delete', 'inactive')
	   AND rosters.season_key = @seasonKey
	   AND rosters.player_key = mapping.player_key
	 WHERE fantasy.league_key = @leagueKey
	   AND fantasy.season_key = @seasonKey
	   AND fantasy.sub_season_key = @subseasonKey
	   AND (ISNULL(@week, '#') = '#' OR fantasy.week = @week)
	   AND (ISNULL(@position, '#') = '#' OR LOWER(fantasy.position) IN (SELECT name from @positions))
	UNION
	SELECT teams.team_key AS player_key, rtfs_id, stats_id, teams.team_last, REPLACE(position, 'DEF', 'DST'),
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(teams.team_first + ' ' + teams.team_last), '/', '-'), '''', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),
			team, 'active', fantasy.week, adp, adp_ytd, adp_lst_30, adp_lst_wk, 
			tot_pts_ytd, tot_pts_lst_30, tot_pts_lst_wk, avg_pts_ytd, avg_pts_lst_30, avg_pts_lst_wk, 
			fnt_lineup, fnt_lineup_ytd, fnt_lineup_lst_30, fnt_lineup_lst_wk, pct_lineup, pct_lineup_ytd, pct_lineup_lst_30, pct_lineup_lst_wk, salary, salary_ytd, salary_lst_30, salary_lst_wk
	  FROM SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
	 INNER JOIN dbo.SMG_Teams teams
		ON teams.team_abbreviation = fantasy.team
	   AND teams.team_first + ' ' + teams.team_last =  fantasy.name
	   AND teams.league_key = fantasy.league_key
	   AND teams.season_key = fantasy.season_key
	 WHERE fantasy.league_key = @leagueKey
	   AND fantasy.season_key = @seasonKey
	   AND fantasy.sub_season_key = @subseasonKey
	   AND (ISNULL(@week, '#') = '#' OR fantasy.week = @week)
	   AND (ISNULL(@position, '#') = '#' OR LOWER(fantasy.position) IN (SELECT name from @positions))

	--Update status
	/*UPDATE temp
	   SET temp.status = rosters.phase_status
	  FROM @info temp
	 INNER JOIN dbo.SMG_Teams teams
	    ON teams.season_key = @seasonKey
	   AND teams.league_key = @leagueKey
	   AND LOWER(teams.team_abbreviation) = LOWER(temp.team)
	 INNER JOIN dbo.SMG_Rosters rosters
		ON rosters.team_key = teams.team_key
	   AND rosters.phase_status NOT IN ('delete', 'inactive')
	   AND rosters.season_key = @seasonKey
	   AND rosters.player_key = temp.player_key;*/

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

    SELECT
	(
        SELECT player_key, rtfs_id, stats_id, name, position, player_slug, team, week,
				adp, salary, status, injury, injury_abbr, injury_details,
				ROW_NUMBER() OVER(ORDER BY CASE WHEN CAST(adp as DECIMAL(15,2)) > 0 THEN CAST(adp as DECIMAL(15,2)) ELSE 9999.99 END, CAST(adp_lst_wk as DECIMAL(15,2)), CAST(tot_pts_ytd as DECIMAL(15,2)) DESC) AS rank
		   FROM @info fantasy
           FOR XML RAW('players'), TYPE
    )
    FOR XML PATH(''), ROOT('fantasy')
    

END

GO
