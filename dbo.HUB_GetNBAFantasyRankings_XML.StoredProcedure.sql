USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNBAFantasyRankings_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNBAFantasyRankings_XML] 
	@date VARCHAR(10) = '2015-10-27',
    @position VARCHAR(10) = 'all',
    @editor VARCHAR(500) = 'numberfire',
    @scoringSystem VARCHAR(100) = 'FantasyScore'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 10/20/2014
-- Description: Get NBA Fantasy Ranking Data
-- Update:		10/27/2014 - pkamat: Get rankings from SMG_Fantasy_NBA_Projections
-- 				10/30/2014 - pkamat: Remove adp, get salary from SMG_Fantasy_RTSports
-- 				10/31/2014 - pkamat: Add slug and opponent for each player
-- 				11/05/2014 - pkamat: Update rank with position rank not for all position
-- 				11/06/2014 - pkamat: Update name and slug for Nene Hilario
-- 				12/01/2014 - pkamat: Added editor name as xml node, points as node value,
--									 Added player last name
-- 				10/20/2015 - pkamat: Move from TSN to SDI provider
--				10/21/2015 - pkamat: Change league key for RTSports
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    
    DECLARE @leagueName VARCHAR(100) = 'nba', @leagueKey VARCHAR(100);
	
   	SELECT @leagueKey =  dbo.SMG_fnGetLeagueKey(LOWER(@leagueName));

	--DECLARE @positions TABLE (name VARCHAR(10), display VARCHAR(10));
	IF (LOWER(@position) = 'all' OR LOWER(@position) = 'flex')
	BEGIN
		--INSERT INTO @positions VALUES('c','C'),('f','F'),('g','G');
		SET @position = NULL;
	END
	ELSE
	BEGIN
		--INSERT INTO @positions VALUES (@position,UPPER(@position));
		SET @position = LOWER(@position);
	END

	DECLARE @info TABLE (
		name			VARCHAR(200),
		last_name		VARCHAR(200),
		player_key		VARCHAR(50),-- PRIMARY KEY, 
		player_slug		VARCHAR(200),
		season_key		VARCHAR(10),
		sub_season_key	VARCHAR(50),
		team			VARCHAR(10),
		opponent		VARCHAR(10),
		position		VARCHAR(10),
		position_reg	VARCHAR(10),
		status			VARCHAR(50),
		injury_abbr		VARCHAR(10) DEFAULT '',
		injury			VARCHAR(100) DEFAULT '',
		injury_details	VARCHAR(MAX) DEFAULT '',
		salary			VARCHAR(10),
		points			DECIMAL(25,2),
		rank_pos		INT,
		rank			INT,
		rank_prev		INT
	);

	--Get the players
	INSERT INTO @info (name,player_key,team,opponent,position,points,rank,rank_pos,season_key,sub_season_key, status)
	SELECT player, projections.player_key, team, opponent, position, points_calculated, rank, rank_pos, season_key, sub_season_key, 'active'
	  FROM SportsEditDB.dbo.SMG_Fantasy_NBA_Projections projections
	 WHERE (ISNULL(@position, '#') = '#' OR LOWER(projections.position) = @position)
	   AND LOWER(projections.editor) = LOWER(@editor)
	   AND LOWER(projections.scoring_system) = LOWER(@scoringSystem)
	   AND projections.date = @date;

	IF (@position IS NOT NULL)
	BEGIN
		UPDATE @info SET rank = rank_pos;
	END

	--Update player slug and last name
	UPDATE temp
	   SET temp.player_slug = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(players.first_name + ' ' + players.last_name), '/', '-'), '''', ''), '.', ''), '&', ''), ' ', '-'), '--', '-'),
			temp.last_name = players.last_name
	  FROM @info temp
	 INNER JOIN dbo.SMG_Players players
		ON temp.player_key = players.player_key;

	--Update salary for players
	UPDATE temp
	   SET temp.salary = fantasy.salary
	  FROM @info temp
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports_Mapping mapping
			ON temp.player_key = mapping.player_key
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
			ON fantasy.stats_id = mapping.rtfs_id
		   AND fantasy.league_key = 'l.nba.com'
		   AND fantasy.season_key = temp.season_key
		   AND fantasy.sub_season_key = temp.sub_season_key
		   AND fantasy.sport_date = @date;

	--Update the injury status of the players
	DECLARE @injuries TABLE (name VARCHAR(100), abbr VARCHAR(10));
	INSERT INTO @injuries VALUES('prob','P'),('ques','Q'),('doub','D'),('out','O'),('injured-reserve','IR'),('physically-unable','PUP');

	UPDATE temp
	   SET temp.status = 'injured', temp.injury = injuries.injury_class, temp.injury_details = injuries.injury_details, 
			temp.injury_abbr = (SELECT abbr FROM @injuries WHERE name = LOWER(LEFT(injuries.injury_class, CHARINDEX(' ', injuries.injury_class) - 1)))
	  FROM @info temp
	 INNER JOIN dbo.SMG_Injuries injuries
		ON temp.player_key = injuries.player_key;

	--Update salary to xx,xxxx
	UPDATE @info
	   SET salary = PARSENAME(CONVERT(VARCHAR,CAST(salary AS MONEY),1),2);

	--Fill all null values
	UPDATE temp
	   SET temp.points = ISNULL(temp.points, 0.0), temp.salary = ISNULL(temp.salary, '0')
	  FROM @info temp;

	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(SELECT CONVERT(XML, '<numberfire>1</numberfire>')
		FOR XML raw('editors'), type
	),
	(SELECT CONVERT(XML, '<name>basketball</name><league_key>' + @leagueKey + '</league_key>')
		FOR XML raw('league'), type
	),
	(
        SELECT 'true' AS 'json:Array', fantasy.player_key, fantasy.name, fantasy.last_name, fantasy.player_slug, fantasy.position, fantasy.position_reg, fantasy.team, fantasy.opponent, fantasy.points, fantasy.salary, fantasy.status, fantasy.injury, fantasy.injury_abbr, fantasy.injury_details,
				fantasy.rank, fantasy.rank_pos,
				(SELECT
					 (SELECT CONVERT(XML, '<' + editor + '>' + CONVERT(VARCHAR, points_calculated) + '</' + editor + '>') 
						FROM SportsEditDB.dbo.SMG_Fantasy_NBA_Projections projections
					   WHERE fantasy.player_key = projections.player_key
					     AND date = @date
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
