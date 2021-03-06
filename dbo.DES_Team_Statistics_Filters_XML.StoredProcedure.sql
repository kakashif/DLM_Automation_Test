USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Statistics_Filters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Statistics_Filters_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100),
   @seasonKey INT,
   @subSeasonType VARCHAR(100),
   @level VARCHAR(100),
   @category VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/16/2015
  -- Description: get team statistics filters for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @team_key VARCHAR(100)

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug
     
    -- levels
    DECLARE @levels TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
	INSERT INTO @levels (display, id)
	VALUES ('Player', 'player'), ('Team', 'team')

    -- verify levels
   	IF NOT EXISTS (SELECT 1 FROM @levels WHERE id = @level)
	BEGIN
	    SELECT TOP 1 @level = id FROM @levels 
	END

	
    -- categorys
    DECLARE @categorys TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
	IF (@leagueName = 'mlb')
	BEGIN
    	INSERT INTO @categorys (display, id)
	    VALUES ('Batting', 'batting'), ('Pitching', 'pitching')
	END
	ELSE IF (@leagueName = 'mls')
	BEGIN
        INSERT INTO @categorys (display, id)
        VALUES ('Offense', 'offense'), ('Goaltending', 'goaltending'), ('Discipline', 'discipline')
	END	
	ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
	BEGIN	    
    	INSERT INTO @categorys (display, id)
	    VALUES ('Offense', 'offense'), ('Defense', 'defense')
	END
	ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
	BEGIN
	    INSERT INTO @categorys (display, id)
	    VALUES ('Offense', 'offense'), ('Defense', 'defense'), ('Special Teams', 'special-teams')
	END	
	ELSE IF (@leagueName = 'nhl')
	BEGIN
	    IF (@level = 'player')
	    BEGIN
            INSERT INTO @categorys (display, id)
            VALUES ('Offense', 'offense'), ('Goaltending', 'goaltending'), ('Special Teams', 'special-teams')
        END
        ELSE
        BEGIN
            INSERT INTO @categorys (display, id)
            VALUES ('Offense', 'offense'), ('Defense', 'defense'), ('Special Teams', 'special-teams')
        END
	END	

    -- verify category
   	IF NOT EXISTS (SELECT 1 FROM @categorys WHERE id = @category)
	BEGIN
	    SELECT TOP 1 @category = id FROM @categorys
	END		

	
    -- year sub season types
    DECLARE @yearSubSeasonTypes TABLE
	(
	    seasonKey INT,
	    subSeasonType VARCHAR(100)
	)    
    INSERT INTO @yearSubSeasonTypes (seasonKey, subSeasonType)
    SELECT season_key, sub_season_type
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND team_key = @team_key AND category = 'feed' AND player_key = 'team'
     GROUP BY season_key, sub_season_type

    -- verify post-season
    IF (@subSeasonType = 'post-season')
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM @yearSubSeasonTypes WHERE seasonKey = @seasonKey AND subSeasonType = 'post-season')
        BEGIN
            SELECT @subSeasonType = 'season-regular'
        END
    END

    -- verify season-key
   	IF NOT EXISTS (SELECT 1 FROM @yearSubSeasonTypes WHERE seasonKey = @seasonKey)
	BEGIN
	    SELECT TOP 1 @seasonKey = seasonKey
	      FROM @yearSubSeasonTypes
	     ORDER BY seasonKey DESC 
	END



    SELECT
    (
        SELECT CONVERT(VARCHAR(100), seasonKey) + '/' + subSeasonType AS id,
               (CASE
                   WHEN @leagueName = 'mlb' THEN CONVERT(VARCHAR(100), seasonKey) +
                                                      ' ' +
                                                      (CASE
                                                          WHEN subSeasonType = 'pre-season' THEN 'Preseason'
                                                          WHEN subSeasonType = 'season-regular' THEN 'Regular Season'
                                                          WHEN subSeasonType = 'post-season' THEN 'Postseason'
                                                      END)
                   ELSE CONVERT(VARCHAR(100), seasonKey) +
                        '-' +
                        RIGHT(CONVERT(VARCHAR(100), seasonKey + 1), 2) +
                        ' ' + (CASE
                                  WHEN subSeasonType = 'pre-season' THEN 'Preseason'
                                  WHEN subSeasonType = 'season-regular' THEN 'Regular Season'
                                  WHEN subSeasonType = 'post-season' THEN 'Postseason'
                              END)
               END) AS display               
          FROM @yearSubSeasonTypes
         ORDER BY seasonKey DESC, subSeasonType ASC
           FOR XML RAW('year_sub_season'), TYPE
    ),
    (
        SELECT id, display
          FROM @levels
           FOR XML RAW('level'), TYPE
    ),
    (
        SELECT id, display
          FROM @categorys
           FOR XML RAW('category'), TYPE
    ),
    (
        SELECT CONVERT(VARCHAR(100), @seasonKey) + '/' + @subSeasonType AS year_sub_season,
               @level AS [level],
               @category AS category
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END


GO
