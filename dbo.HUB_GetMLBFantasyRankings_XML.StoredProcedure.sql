USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetMLBFantasyRankings_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetMLBFantasyRankings_XML] 
	@date VARCHAR(10) = '2015-04-05',
    @position VARCHAR(10) = 'all',
    @editor VARCHAR(500) = 'numberfire',
    @scoringSystem VARCHAR(100) = 'FantasyScore'
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 03/26/2015
-- Description: Get MLB Fantasy Ranking Data
-- Update: 		03/30/2015 - pkamat - Update rank for positions
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    
    DECLARE @leagueName VARCHAR(100) = 'mlb', @leagueKey VARCHAR(100);
	
   	SELECT @leagueKey = league_display_name
	  FROM dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName);

	DECLARE @positions TABLE (name VARCHAR(10));
	IF (LOWER(@position) = 'all')
	BEGIN
		SET @position = NULL;
	END
	ELSE
	BEGIN
		INSERT INTO @positions VALUES(LOWER(@position));
	END

	DECLARE @info TABLE (
		name			VARCHAR(200),
		last_name		VARCHAR(200),
		player_key		VARCHAR(50),-- PRIMARY KEY, 
		player_slug		VARCHAR(200),
		season_key		VARCHAR(10),
		team			VARCHAR(10),
		opponent		VARCHAR(10),
		position		VARCHAR(10),
		position_reg	VARCHAR(10),
		status			VARCHAR(50),
		injury_abbr		VARCHAR(5) DEFAULT '',
		injury			VARCHAR(100) DEFAULT '',
		injury_details	VARCHAR(100) DEFAULT '',
		salary			VARCHAR(10),
		points			DECIMAL(25,2),
		rank_pos		INT,
		rank			INT,
		rank_prev		INT
	);

	--Get the players
	INSERT INTO @info (name,last_name,player_key,player_slug,team,opponent,position,points,rank,rank_pos,season_key)
	SELECT player, last_name, player_key, player_slug, team, opponent, position, points_calculated, rank, rank_pos, season_key
	  FROM SportsEditDB.dbo.SMG_Fantasy_MLB_Projections projections
	 WHERE (ISNULL(@position, '#') = '#' OR LOWER(projections.position) LIKE (SELECT '%' + name + '%' from @positions))
	   AND LOWER(projections.editor) = LOWER(@editor)
	   AND LOWER(projections.scoring_system) = LOWER(@scoringSystem)
	   AND projections.date = @date;

	IF (@position IS NOT NULL)
	BEGIN
		--UPDATE @info SET rank = rank_pos;
		UPDATE temp
		   SET temp.rank = ranks.rank
		  FROM @info temp
		 INNER JOIN (SELECT player_key, ROW_NUMBER() OVER(ORDER BY points DESC, name ASC) AS rank 
					   FROM @info 
					) ranks
			ON temp.player_key = ranks.player_key;
	END

	--Update salary for players
	UPDATE temp
	   SET temp.salary = fantasy.salary
	  FROM @info temp
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports_Mapping mapping
			ON temp.player_key = mapping.player_key
	 INNER JOIN SportsEditDB.dbo.SMG_Fantasy_RTSports fantasy
			ON fantasy.stats_id = mapping.rtfs_id
		   AND fantasy.league_key = @leagueKey
		   AND fantasy.season_key = temp.season_key
		   AND fantasy.sport_date = @date;

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
	   SET temp.points = ISNULL(temp.points, 0.0), temp.salary = ISNULL(temp.salary, '0')
	  FROM @info temp;

	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(SELECT CONVERT(XML, '<numberfire>1</numberfire>')
		FOR XML raw('editors'), type
	),
	(
        SELECT fantasy.player_key, fantasy.name, fantasy.last_name, fantasy.player_slug, fantasy.position, fantasy.position_reg, fantasy.team, fantasy.opponent, fantasy.points, fantasy.salary, fantasy.status, fantasy.injury, fantasy.injury_abbr, fantasy.injury_details,
				fantasy.rank, fantasy.rank_pos,
				(SELECT
					 (SELECT CONVERT(XML, '<' + editor + '>' + CONVERT(VARCHAR, points_calculated) + '</' + editor + '>') 
						FROM SportsEditDB.dbo.SMG_Fantasy_MLB_Projections projections
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
