USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetTeamPicker_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetTeamPicker_XML]
    @leagueName	VARCHAR(100),
	@seasonKey	INT	
AS
-- =============================================
-- Author:     	ikenticus
-- Create date: 05/20/2015
-- Description: get team picker info for desktop
-- Update: 06/16/2015 - John Lin - exclude teams without conference or division
--         07/07/2015 - John Lin - update MLS
--         07/23/2015 - John Lin - update MLB
--         08/21/2015 - John Lin - SDI migration
--         08/25/2015 - John Lin - NCAAF update conference key with conference slug
--         09/03/2015 - ikenticus - replace order by conference_key with conference_order
--         10/21/2015 - ikenticus - NCAAB/NCAAW update conference key with conference slug
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	

	-- Determine leagueKey from leagueName
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	-- Check for valid seasonKey
	IF @seasonKey NOT IN (SELECT season_key
	                        FROM dbo.SMG_Teams
	                       WHERE league_key = @league_key
	                       GROUP BY season_key)
	BEGIN
		SELECT @seasonKey = season_key
		  FROM SMG_Default_Dates
		 WHERE league_key = @leagueName AND page = 'statistics'
	END


	DECLARE @leagues TABLE (
		division_key VARCHAR(100),
		division_name VARCHAR(100),
		division_order INT,
		conference_key VARCHAR(100),
		conference_name VARCHAR(100),
		conference_order INT
	)
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
    	INSERT INTO @leagues (conference_key, conference_order, conference_name, division_key, division_order, division_name)
	    SELECT conference_key, conference_order, conference_display, division_key, division_order, division_display
	      FROM dbo.SMG_Leagues
	     WHERE league_key = @league_key AND season_key = @seasonKey AND tier = 1
    END
    ELSE
    BEGIN
    	INSERT INTO @leagues (conference_key, conference_order, conference_name, division_key, division_order, division_name)
	    SELECT conference_key, conference_order, conference_display, division_key, division_order, division_display
	      FROM dbo.SMG_Leagues
	     WHERE league_key = @league_key AND season_key = @seasonKey
    END

    -- remove extra feed
    IF (@leagueName IN ('mlb'))
    BEGIN
        DELETE @leagues
         WHERE conference_key IS NULL OR conference_key = ''

        DELETE @leagues
         WHERE division_key IS NULL OR division_key = ''
    END

	DECLARE @teams TABLE (
		first_name VARCHAR(100),
		last_name VARCHAR(100),
		team_key VARCHAR(100),
		team_name VARCHAR(100),
		team_slug VARCHAR(100),
		conference_key VARCHAR(100),
		division_key VARCHAR(100),
		name_order INT IDENTITY(1, 1)
	)

	INSERT INTO @teams (team_key, first_name, last_name, team_slug, team_name, conference_key, division_key)
	SELECT team_key, team_first, team_last, team_slug, team_display, conference_key, division_key
	  FROM dbo.SMG_Teams 
	 WHERE league_key = @league_key AND season_key = @seasonKey AND 'All-Stars' NOT IN (team_first, team_last)
	 ORDER BY team_first ASC

	UPDATE @teams
	   SET team_name = NULL
	 WHERE team_name = ''

	UPDATE @teams
	   SET last_name = NULL
	 WHERE last_name = ''

	DECLARE @ribbon VARCHAR(100)
	DECLARE @median INT

	SET @ribbon = CASE
					WHEN @leagueName = 'champions' THEN 'Champions League'
					WHEN @leagueName = 'wwc' THEN 'Women''s World Cup'
					WHEN @leagueName = 'natl' THEN 'World Cup'
					ELSE UPPER(@leagueName) END



	IF (@leagueName IN ('nfl'))
    BEGIN
        SELECT @ribbon AS ribbon,
	    (
            SELECT c.conference_key, c.conference_name,
                   (
                       SELECT d.division_key, d.division_name,		
                              (
                                  SELECT '1' AS first_name_display, first_name, last_name, team_key, team_name, team_slug
                                    FROM @teams AS t
								   WHERE t.conference_key = c.conference_key AND ISNULL(t.division_key, '') = ISNULL(d.division_key, '')
								   ORDER BY first_name ASC, last_name ASC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM @leagues AS d
                        WHERE d.conference_key = c.conference_key
						GROUP BY d.division_key, d.division_name, d.division_order
                        ORDER BY d.division_order ASC
                          FOR XML RAW('division'), TYPE
                   )
              FROM @leagues AS c
			 GROUP BY c.conference_key, c.conference_name, c.conference_order
             ORDER BY c.conference_order
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
	ELSE IF (@leagueName IN ('ncaaf'))
    BEGIN
		UPDATE @teams
		   SET team_name = first_name

        SELECT @ribbon AS ribbon,
	    (
            SELECT SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_name) AS conference_key, l.conference_name,
				  (
					  SELECT first_name, last_name, team_key, team_name, team_slug
						FROM @teams AS t
					   WHERE t.conference_key = l.conference_key
					   ORDER BY first_name ASC, last_name ASC
						 FOR XML RAW('team'), TYPE
				  )
              FROM @leagues AS l
             GROUP BY l.conference_key, l.conference_name, l.conference_order
             ORDER BY l.conference_order ASC
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
	ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
		UPDATE @teams
		   SET team_name = first_name

        SELECT @ribbon AS ribbon,
	    (
            SELECT SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_name) AS conference_key, l.conference_name,
				  (
					  SELECT first_name, last_name, team_key, team_name, team_slug
						FROM @teams AS t
					   WHERE t.conference_key = l.conference_key
					   ORDER BY first_name ASC, last_name ASC
						 FOR XML RAW('team'), TYPE
				  )
              FROM @leagues AS l
             ORDER BY conference_order

               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('natl', 'wwc', 'champions'))
    BEGIN
		UPDATE @teams
		   SET team_name = first_name
		 WHERE team_name IS NULL

        SELECT @ribbon AS ribbon,
	    (
			SELECT d.division_key, d.division_name,		
				(
					SELECT first_name, last_name, team_key, team_name, team_slug
					  FROM @teams AS t
					 WHERE t.division_key = d.division_key
					 ORDER BY first_name ASC, last_name ASC
					   FOR XML RAW('team'), TYPE
				)
			  FROM @leagues AS d
			 GROUP BY d.division_key, d.division_name, d.division_order
			 ORDER BY d.division_order ASC
			   FOR XML RAW('division'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName ='epl')
    BEGIN
		-- Simulate divisions to produce two column display
		SELECT @median = COUNT(*) / 2
		  FROM @teams

		UPDATE @teams
		   SET division_key = CASE WHEN name_order <= @median THEN 1 ELSE 2 END

		UPDATE @teams
		   SET team_name = first_name
		 WHERE team_name IS NULL

        SELECT @ribbon AS ribbon,
	    (
			SELECT d.division_key,
				(
					SELECT first_name, last_name, team_key, team_name, team_slug
					  FROM @teams AS t
					 WHERE t.division_key = d.division_key
					 ORDER BY first_name ASC, last_name ASC
					   FOR XML RAW('team'), TYPE
				)
			  FROM @teams AS d
			 GROUP BY d.division_key
			 ORDER BY d.division_key ASC
			   FOR XML RAW('division'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
	ELSE IF (@leagueName IN ('mls', 'wnba'))
    BEGIN
		UPDATE @teams
		   SET team_name = last_name
		 WHERE team_name IS NULL

        SELECT @ribbon AS ribbon,
	    (
            SELECT 'MLS' AS conference_name,
                   (
                       SELECT c.conference_name AS division_name, 'CONFERENCE' AS conference_only,			
                              (
                                  SELECT '1' AS first_name_display, first_name, last_name, team_key, team_name, team_slug
                                    FROM @teams AS t
								   WHERE t.conference_key = c.conference_key
								   ORDER BY first_name ASC, last_name ASC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM @leagues AS c
			            GROUP BY c.conference_key, c.conference_name, c.conference_order
						ORDER BY c.conference_order ASC
                          FOR XML RAW('division'), TYPE
                   )
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
	ELSE
    BEGIN
		UPDATE @teams
		   SET team_name = last_name
		 WHERE team_name IS NULL

        SELECT @ribbon AS ribbon,
	    (
            SELECT c.conference_key, c.conference_name,
                   (
                       SELECT d.division_key, d.division_name,		
                              (
                                  SELECT '1' AS first_name_display, first_name, last_name, team_key, team_name, team_slug
                                    FROM @teams AS t
								   WHERE t.conference_key = c.conference_key AND t.division_key = d.division_key
								   ORDER BY first_name ASC, last_name ASC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM @leagues AS d
                        WHERE d.conference_key = c.conference_key
						GROUP BY d.division_key, d.division_name, d.division_order
                        ORDER BY d.division_order ASC
                          FOR XML RAW('division'), TYPE
                   )
              FROM @leagues AS c
			 GROUP BY c.conference_key, c.conference_name, c.conference_order
             ORDER BY c.conference_order ASC
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END 

GO
