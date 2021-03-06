USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Statistics_Filters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_Statistics_Filters_XML]
   @leagueName VARCHAR(100),
   @seasonKey INT,
   @subSeasonType VARCHAR(100),
   @affiliation VARCHAR(100),
   @level VARCHAR(100),
   @category VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/04/2013
  -- Description: get statistics filters
  -- Update:      07/26/2013 - John Lin - football statistics
  --              09/05/2013 - John Lin - fix NCAA logic
  --              02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
  --              03/10/2015 - John Lin - deprecate SMG_NCAA table
  --              03/18/2015 - ikenticus - correcting the default season/subseason logic
  --              06/05/2015 - ikenticus - supporting leagueName in addition to leagueKey
  --              08/11/2015 - John Lin - SDI migration
  --              08/28/2015 - ikenticus - adding MLB to new filters affiliation logic
  --              09/08/2015 - John Lin - add WNBA to new filters affiliation logic
  --              10/16/2015 - ikenticus - SDI sends regular-season rank during pre-season, so exclude from season dropdown logic
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)


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

    -- affiliations
    DECLARE @affiliations TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
    -- categorys
    DECLARE @categorys TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
	IF (@leagueName = 'mlb')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('All MLB', 'all')

    	INSERT INTO @categorys (display, id)
	    VALUES ('Batting', 'batting'), ('Pitching', 'pitching')
	END
	ELSE IF (@leagueName = 'mls')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('All MLS', 'all')

        INSERT INTO @categorys (display, id)
        VALUES ('Offense', 'offense'), ('Goaltending', 'goaltending'), ('Discipline', 'discipline')
	END
	ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
	BEGIN
	    IF (@leagueName = 'nba')
	    BEGIN
    	    INSERT INTO @affiliations (display, id)
	        VALUES ('All NBA', 'all')
	    END
	    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    	BEGIN
    	    IF (@leagueName = 'ncaab')
        	BEGIN
    	        INSERT INTO @affiliations (display, id)
        	    VALUES ('All NCAAB', 'all')
        	END
        	ELSE
        	BEGIN
	            INSERT INTO @affiliations (display, id)
    	        VALUES ('All NCAAW', 'all')
        	END
        END
    	ELSE
	    BEGIN
	        INSERT INTO @affiliations (display, id)
    	    VALUES ('All WNBA', 'all')
	    END
        
    	INSERT INTO @categorys (display, id)
	    VALUES ('Offense', 'offense'), ('Defense', 'defense')
	END
	ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
	BEGIN
	    INSERT INTO @categorys (display, id)
	    VALUES ('Offense', 'offense'), ('Defense', 'defense'), ('Special Teams', 'special-teams')

	    IF (@leagueName = 'ncaaf')
	    BEGIN
	        INSERT INTO @affiliations (display, id)
    	    VALUES ('All NCAAF', 'all')
	    END
	    ELSE
    	BEGIN
	        INSERT INTO @affiliations (display, id)
	        VALUES ('All NFL', 'all')
	    END
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('All NHL', 'all')

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

    IF (@leagueName IN ('ncaaf'))
    BEGIN
        INSERT INTO @affiliations (display, id)
        SELECT conference_display, SportsEditDb.dbo.SMG_fnSlugifyName(conference_display)
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @seasonKey AND tier = 1 AND conference_key IS NOT NULL
         GROUP BY conference_key, conference_display, conference_order
         ORDER BY conference_order ASC
    END
    ELSE IF (@leagueName IN ('mlb', 'nfl', 'wnba'))
    BEGIN
        INSERT INTO @affiliations (display, id)
        SELECT conference_display, SportsEditDb.dbo.SMG_fnSlugifyName(conference_display)
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @seasonKey AND conference_key IS NOT NULL
         GROUP BY conference_key, conference_display, conference_order
         ORDER BY conference_order ASC
    END
    ELSE
    BEGIN
        INSERT INTO @affiliations (display, id)
        SELECT conference_display, conference_key
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @seasonKey AND conference_key IS NOT NULL
         GROUP BY conference_key, conference_display, conference_order
         ORDER BY conference_order ASC
	END
	
	-- verify affiliation
    IF NOT EXISTS (SELECT 1 FROM @affiliations WHERE id = @affiliation)
    BEGIN
        SELECT TOP 1 @affiliation = id FROM @affiliations
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
	    subSeasonType VARCHAR(100),
		priority INT
	)    
    INSERT INTO @yearSubSeasonTypes (seasonKey, subSeasonType)
    SELECT season_key, sub_season_type
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND category = 'feed' AND player_key = 'team'
	   AND [column] NOT IN ('conference_ranking', 'division_ranking')
     GROUP BY season_key, sub_season_type

	-- Set up priority
	UPDATE @yearSubSeasonTypes
	   SET priority = 1
	 WHERE subSeasonType = 'post-season'

	UPDATE @yearSubSeasonTypes
	   SET priority = 2
	 WHERE subSeasonType = 'season-regular'

	UPDATE @yearSubSeasonTypes
	   SET priority = 3
	 WHERE subSeasonType = 'pre-season'

    -- verify season-key
   	IF NOT EXISTS (SELECT 1 FROM @yearSubSeasonTypes WHERE seasonKey = @seasonKey)
	BEGIN
	    SELECT TOP 1 @seasonKey = seasonKey
	      FROM @yearSubSeasonTypes
	     ORDER BY seasonKey DESC

	    SELECT TOP 1 @subSeasonType = subSeasonType
	      FROM @yearSubSeasonTypes
	     ORDER BY seasonKey DESC, priority ASC
	END

	-- verify subseason
	IF NOT EXISTS (SELECT 1 FROM @yearSubSeasonTypes WHERE seasonKey = @seasonKey AND subSeasonType = @subSeasonType)
	BEGIN
	    SELECT TOP 1 @subSeasonType = subSeasonType
	      FROM @yearSubSeasonTypes
	     ORDER BY seasonKey DESC, priority ASC
	END

    
    SELECT
    (
        SELECT CONVERT(VARCHAR(100), seasonKey) + '/' + subSeasonType AS id,
               (CASE
                   WHEN @leagueName IN ('mlb', 'mls', 'wnba') THEN CONVERT(VARCHAR(100), seasonKey) + ' ' +
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
         ORDER BY seasonKey DESC, priority ASC
           FOR XML RAW('year_sub_season'), TYPE
    ),
    (
        SELECT id, display
          FROM @affiliations
           FOR XML RAW('affiliation'), TYPE
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
               @affiliation AS affiliation,
               @level AS [level],
               @category AS category
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END


GO
