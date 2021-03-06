USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetRankings_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetRankings_XML]
	@leagueName VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/03/2014
-- Description: get default ranking for Jameson
-- Update:      09/08/2014 - ikenticus - using whitebg logos for NCAA
--              09/09/2014 - John Lin - negate rank difference
--              11/06/2014 - John Lin - add header image
--              11/11/2014 - John Lin - add header directory
--				01/26/2015 - ikenticus - add ribbons
--				07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--              10/15/2015 - John Lin - SDI migration
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
    DECLARE @week INT
    DECLARE @header_image VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/header/amway_coaches_poll.png'
	
    IF (@leagueName = 'ncaab')
    BEGIN
        SET @header_image = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/header/coaches_poll.png'
    END
    ELSE IF (@leagueName = 'ncaaw')
    BEGIN
        SET @header_image = ''
    END

    SELECT TOP 1 @season_key = season_key, @week = [week]
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @leagueName AND fixture_key = 'smg-usat'
     ORDER BY poll_date DESC

	DECLARE @polls TABLE (
		poll_date		 DATE,
        points           INT,
        ranking          INT,
        ranking_previous VARCHAR(100),
        record           VARCHAR(100),        
        ranking_diff	 INT,
		ranking_mover	 VARCHAR(100),
		-- extra
        name             VARCHAR(100),
        abbr             VARCHAR(100),
        logo             VARCHAR(100)
	)

	INSERT INTO @polls (abbr, name, points, ranking, ranking_previous, record, ranking_diff, ranking_mover, poll_date)
	SELECT st.team_abbreviation, st.team_first, sp.points, sp.ranking, ISNULL(sp.ranking_previous, 'NR'),
	       CAST(sp.wins AS VARCHAR) + '-' + CAST(sp.losses AS VARCHAR), sp.ranking_diff, sp.ranking_mover, sp.poll_date
	  FROM SportsEditDB.dbo.SMG_Polls AS sp
	 INNER JOIN dbo.SMG_Teams AS st ON st.season_key = sp.season_key AND st.team_abbreviation= sp.team_key
	 WHERE sp.league_key = @leagueName AND st.league_key = @league_key AND sp.season_key = @season_key
       AND sp.fixture_key = 'smg-usat' AND sp.[week] = @week

    UPDATE @polls
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/110/' + abbr + '.png',
           ranking_diff = (-1 * ranking_diff) -- For RANK, negate the difference      
    

	-- Check for sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@leagueName) AND page_id = 'smg-usat' AND name = 'sponsor'

	IF (@sponsor IS NULL)
	BEGIN
		SET @sponsor = 'USA TODAY'
	END

	-- Add ribbon information
	DECLARE @ribbon VARCHAR(100) = @sponsor + ' Coaches Poll'
	DECLARE @sub_ribbon VARCHAR(100)

	SELECT TOP 1 @sub_ribbon = 'Published On: ' + CAST(poll_date AS VARCHAR(100))
	  FROM @polls


    SELECT @ribbon AS ribbon, @sub_ribbon AS sub_ribbon, @header_image AS header_image,
    (
        SELECT ranking, logo, name, record, points, ranking_diff
	      FROM @polls
		 ORDER BY ranking ASC, record DESC
		   FOR XML RAW('poll'), TYPE
    ),
	(
		SELECT
		(
		    SELECT logo, name, ranking, ranking_diff, ranking_previous
		      FROM @polls
			 WHERE ranking_mover = 'RISE'
			   FOR XML RAW('rise'), TYPE
		),
		(
			SELECT logo, name, ranking, ranking_diff, ranking_previous
			  FROM @polls
		     WHERE ranking_mover = 'FALL'
			   FOR XML RAW('fall'), TYPE
		)
		FOR XML RAW('movers'), TYPE
	)

	FOR XML RAW('root'), TYPE

	
END


GO
