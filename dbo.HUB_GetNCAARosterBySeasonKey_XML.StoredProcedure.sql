USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAARosterBySeasonKey_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[HUB_GetNCAARosterBySeasonKey_XML]
    @teamSlug VARCHAR(100),
    @sport VARCHAR(100),
	@seasonKey INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/07/2014
  -- Description: get roster for ncaa team
  -- Update: 09/05/2014 - John Lin - abbreviate class
  --         11/19/2014 - John Lin - men -> mens, add basketball
  --         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         03/26/2015 - John Lin - seperate out default year
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @team_key VARCHAR(100)
    DECLARE @league_key VARCHAR(100) = 'l.ncaa.org.mfoot'
    DECLARE @league_name VARCHAR(100) = 'ncaaf'

    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )

    IF (@sport = 'football')
    BEGIN
        INSERT INTO @tables (table_name, table_display)
        VALUES ('offense', 'offense'), ('defense', 'defense'), ('special_team', 'special team')
    END
    ELSE
    BEGIN
        INSERT INTO @tables (table_name, table_display)
        VALUES ('roster', 'roster')

		IF (@sport = 'mens-basketball')
		BEGIN
            SET @league_key = 'l.ncaa.org.mbasket'
            SET @league_name = 'ncaab'
		END
		ELSE IF (@sport = 'womens-basketball')
		BEGIN
            SET @league_key = 'l.ncaa.org.wbasket'
            SET @league_name = 'ncaaw'
		END
    END

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug


    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
	INSERT INTO @columns (column_name, column_display)
	VALUES ('uniform_number', 'NO'), ('full_name', 'NAME'), ('position_regular', 'POS'), ('height', 'HT'), ('weight', 'WT'), ('class', 'CLASS')


	DECLARE @roster TABLE
	(
		player_key		 VARCHAR(100),
		uniform_number	 VARCHAR(100),
		full_name		 VARCHAR(100),
		position_regular VARCHAR(100),
		height			 VARCHAR(100),
		[weight]         INT,
		class			 VARCHAR(100)
	)
	INSERT INTO @roster (player_key, uniform_number, full_name, position_regular, height, [weight], class)
    SELECT p.player_key, r.uniform_number, p.first_name + ' ' + p.last_name, r.position_regular, r.height, r.[weight], r.subphase_type
	  FROM dbo.SMG_Rosters AS r
	 INNER JOIN dbo.SMG_Players AS p
		ON p.player_key = r.player_key
	 WHERE r.season_key = @seasonKey AND r.team_key = @team_key AND r.phase_status = 'active'

   UPDATE @roster
      SET class = 'Fr.'
    WHERE class = 'freshman'

   UPDATE @roster
      SET class = 'So.'
    WHERE class = 'sophomore'

   UPDATE @roster
      SET class = 'Jr.'
    WHERE class = 'junior'

   UPDATE @roster
      SET class = 'Sr.'
    WHERE class = 'senior'

    -- leaders
    DECLARE @leaders TABLE
    (
        category_order INT,
        category       VARCHAR(100),
        player_key     VARCHAR(100),
        name           VARCHAR(100),
        value          VARCHAR(100)
    )

    IF (@sport = 'football')
    BEGIN
		-- passing
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 1, 'passing', player_key, value
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'passes-yards-gross' AND player_key <> 'team'
		 ORDER BY CAST(value AS INT) DESC

		-- rushing
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 2, 'rushing', player_key, value
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'rushes-yards' AND player_key <> 'team'
		 ORDER BY CAST(value AS INT) DESC

		-- receiving
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 3, 'receiving', player_key, value
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'receptions-yards' AND player_key <> 'team'
		 ORDER BY CAST(value AS INT) DESC
    END
    ELSE
    BEGIN
		-- points
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 1, 'points', player_key, value
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'points-scored-per-game' AND player_key <> 'team'
		 ORDER BY CAST(value AS FLOAT) DESC

		-- rebound
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 2, 'rebounds', player_key, value
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'rebounds-per-game' AND player_key <> 'team'
		 ORDER BY CAST(value AS FLOAT) DESC

		-- assist
		INSERT INTO @leaders (category_order, category, player_key, value)
		SELECT TOP 3 3, 'assists', player_key, CAST(value AS DECIMAL(3, 1))
		  FROM SportsEditDB.dbo.SMG_Statistics
		 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
			   team_key = @team_key AND [column] = 'assists-total-per-game' AND player_key <> 'team'
		 ORDER BY CAST(value AS FLOAT) DESC
    END

	 UPDATE l
	    SET l.name = sp.first_name + ' ' + sp.last_name
	   FROM @leaders l
	  INNER JOIN dbo.SMG_Players sp
         ON sp.player_key = l.player_key




	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
    (
        SELECT category,
               (
                   SELECT name, value
                     FROM @leaders l_i
                    WHERE l_i.category = l.category
                      FOR XML RAW('rows'), TYPE
               )
          FROM @leaders l
         GROUP BY category, category_order
         order BY category_order ASC
           FOR XML RAW('leaders'), TYPE
    ),
	(
		SELECT column_name, column_display
		  FROM @columns
		 ORDER BY id ASC
		   FOR XML RAW('columns'), TYPE
	),
	(
	    SELECT 'true' AS 'json:Array',
	           table_display,
	           (
		           SELECT player_key, uniform_number, full_name, position_regular, height, [weight], class
		             FROM @roster
		            WHERE table_name = 'offense' AND
		                  (CASE
		                      WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
			                  ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
			              END) IN ('C', 'FB', 'G', 'HB', 'OL', 'QB', 'RB', 'SB', 'TB', 'OT', 'TE', 'WR')
		            ORDER BY uniform_number
		              FOR XML RAW('rows'), TYPE
	           ),
	           (
		           SELECT player_key, uniform_number, full_name, position_regular, height, [weight], class
		             FROM @roster
                    WHERE table_name = 'defense' AND
                          (CASE
		                      WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
            		          ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
			              END) IN ('CB', 'DE', 'DB', 'DL', 'DT', 'FS', 'LB', 'NG', 'S', 'SS')
            		ORDER BY uniform_number
                      FOR XML RAW('rows'), TYPE
	           ),
               (
            	   SELECT player_key, uniform_number, full_name, position_regular, height, [weight], class
            		 FROM @roster
                    WHERE table_name = 'special_team' AND
            		      (CASE
		                       WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
            				   ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
			               END) IN ('LS', 'KR', 'P', 'PK', 'PR')
            		 ORDER BY uniform_number
                       FOR XML RAW('rows'), TYPE
	           ),
               (
            	   SELECT player_key, uniform_number, full_name, position_regular, height, [weight], class
            		 FROM @roster
                    WHERE table_name = 'roster' AND
            		      (CASE
		                       WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
            				   ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
			               END) IN ('C', 'F', 'G')
            		 ORDER BY uniform_number
                       FOR XML RAW('rows'), TYPE
	           )
	      FROM @tables
	     ORDER BY id ASC
	       FOR XML RAW('table'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END

GO
