USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLFantasyPlayers_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNFLFantasyPlayers_XML]
	@leagueKey VARCHAR(100) = 'l.nfl.com',
	@seasonKey VARCHAR(10) = '2014'
AS
--=============================================
-- Author:      Prashant Kamat
-- Create date: 10/16/2014
-- Description: Get NFL Fantasy Players for a league and season
-- Update:		10/27/2014 - pkamat: Shorten the first name to initial for players, last name for teams
--									 Add opponent for each player, order of display
-- 				10/29/2014 - pkamat: Keep player and team name as is
-- 				11/04/2014 - pkamat: Add first and last name for player and team, add type, week, subseason
-- 				11/24/2014 - pkamat: Make next week's players available by mon 6am
-- 				01/26/2015 - pkamat: Added superbowl week for post season
--              01/29/2015 - John Lin - rename championship to conference
-- 		   		06/08/2015 - pkamat - Remove " from player names
-- 		   		06/09/2015 - pkamat - Include inactive players
-- 		   		06/28/2015 - pkamat: Added player key and team key as PRIMARY KEYS
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @positions TABLE (name VARCHAR(10), display VARCHAR(10), ord INT);
	INSERT INTO @positions VALUES ('qb','QB',1),('rb','RB',2),('fb','RB',2),('fb/rb','RB',2),('wr','WR',3),('wr/kr','WR',3),('wr/pr','WR',3),('wr/rb','WR',3),('te','TE',4),('te/fb','TE',4),('d','D',5),('pk','PK',6),('kr/pr','KR',7);

	DECLARE @info TABLE (
		name			VARCHAR(200),
		player_key		VARCHAR(50), 
		first_name		VARCHAR(200),
		last_name		VARCHAR(200),
		team			VARCHAR(10),
		team_key		VARCHAR(50), 
		opponent		VARCHAR(10),
		position		VARCHAR(10),
		ord				INT,
		status			VARCHAR(50),
		type			VARCHAR(10),
		PRIMARY KEY (player_key, team_key)
	);

	DECLARE @week VARCHAR(10), @subSeasonKey VARCHAR(100);
	select @week = week, @subSeasonKey = sub_season_type 
	  FROM dbo.SMG_Default_Dates 
	 WHERE league_key = 'nfl' 
	   AND page = 'schedules'
	   AND season_key = @seasonKey;

	DECLARE @curdatetime DATETIME = DATEADD(DAY, 0, GETDATE());--Used to test different date scenarios
	DECLARE @curdate DATETIME = CONVERT(DATE, @curdatetime);
	DECLARE @mon6AM DATETIME = DATEADD(DAY, 2 - DATEPART(dw, @curdate), @curdate) + '06:00:00.0', @tue11AM DATETIME = DATEADD(DAY, 3 - DATEPART(dw, @curdate), @curdate) + '11:00:00.0';

	IF (DATEDIFF(SECOND, @mon6AM, @curdatetime) > 0 AND DATEDIFF(SECOND, @curdatetime, @tue11AM) > 0 ) --Check if current time is between mon 6 am and tue 11 am
	BEGIN
		IF (LOWER(@subSeasonKey) = 'season-regular')
		BEGIN
			IF (LOWER(@week) = '17')
			BEGIN
				SELECT @week = 'wild-card', @subSeasonKey = 'post-season';
			END
			ELSE
			BEGIN
				SELECT @week = CAST(@week as INT) + 1;
			END
		END
		ELSE IF (LOWER(@subSeasonKey) = 'post-season')
		BEGIN
			IF (LOWER(@week) = 'pro-bowl')
			BEGIN
				SELECT @week = 'super-bowl';
			END
			ELSE IF (LOWER(@week) = 'divisional')
			BEGIN
				SELECT @week = 'conference';
			END
			ELSE IF (LOWER(@week) = 'wild-card')
			BEGIN
				SELECT @week = 'divisional';
			END
		END
	END

	DECLARE @teams TABLE (team_key VARCHAR(100), opp VARCHAR(100));

	INSERT INTO @teams
	SELECT home_team_key, away_team_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = @subSeasonKey AND [week] = @week
	UNION
	SELECT away_team_key, home_team_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = @subSeasonKey AND [week] = @week;

	INSERT INTO @info(name,first_name,last_name,player_key,team,team_key,opponent,position,ord,status,type)
	SELECT REPLACE(REPLACE(players.first_name + ' ' + players.last_name, '''', ''), '"', '') as name, 
			REPLACE(REPLACE(players.first_name, '''', ''), '"', '') as first_name, 
			REPLACE(REPLACE(players.last_name, '''', ''), '"', '') as last_name, 
			players.player_key, teams.team_abbreviation, teams.team_key, null, positions.display, positions.ord, rosters.phase_status, 'player'
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
	   AND rosters.phase_status NOT IN ('delete')--, 'inactive')
	 INNER JOIN @positions positions
		ON LOWER(rosters.position_regular) = positions.name

	INSERT INTO @info(name,first_name,last_name,player_key,team,team_key,opponent,position,ord,status,type)
	SELECT teams.team_first + ' ' + teams.team_last as name, teams.team_first, teams.team_last, teams.team_key, teams.team_abbreviation, teams.team_key, null, 'D', 5, 'active', 'team'
	  FROM dbo.SMG_Teams teams
	 INNER JOIN @teams teams1
		ON teams1.team_key = teams.team_key
	 WHERE teams.league_key = @leagueKey
	   AND teams.season_key = @seasonKey;

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

	--Delete player l.nfl.com-p.12859 Keith Wenning
	DELETE @INFO WHERE player_key = 'l.nfl.com-p.12859' AND status = 'inactive'

    SELECT @seasonKey as season, @subSeasonKey as sub_season, @week as week,
	(
		SELECT name, player_key, team, position, opponent, first_name, last_name, type, status
		  FROM @info
		 ORDER BY team, ord, name
           FOR XML RAW('players'), TYPE
    )
    FOR XML PATH(''), ROOT('fantasy')

END

GO
