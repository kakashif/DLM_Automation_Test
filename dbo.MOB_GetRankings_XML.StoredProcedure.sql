USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetRankings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetRankings_XML] 
	@leagueName VARCHAR(100)
AS
-- =============================================
-- Author:		John LIn
-- Create date: 04/15/2015
-- Description:	get power rankings for mobile
-- Update: 05/18/2015 - John Lin - return error
--         06/23/2015 - John Lin - STATS migration
--		   06/24/2015 - ikenticus: removing TSN/XTS league_key
--         07/10/2015 - John Lin - STATS team records
--         09/22/2015 - John Lin - team key for team and team slug for ranking
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb', 'nba', 'nfl', 'nhl'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
	DECLARE @week INT
	DECLARE @week_begin DATE

	SELECT TOP 1 @week = [week], @season_key = season_key, @week_begin = week_begin
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND week_begin < GETDATE()
	 ORDER BY season_key DESC, [week] DESC

	DECLARE @rankings TABLE 
	(
	    ranking       INT,
		ranking_diff  INT,
		ranking_hilo  VARCHAR(100),
        record        VARCHAR(100),
		ranking_mover VARCHAR(100),
		-- extra
		team_key      VARCHAR(100),
		team_slug     VARCHAR(100),
		team_abbr     VARCHAR(100),
		team_logo     VARCHAR(100),
		team_page     VARCHAR(100)		
	)
	INSERT INTO @rankings (team_slug, ranking, ranking_diff, ranking_mover, ranking_hilo)
	SELECT team_key, ranking, ranking_diff, ranking_mover, ranking_hilo
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND season_key = @season_key AND [week] = @week

	UPDATE r
	   SET r.team_key = st.team_key,
	   	   r.team_abbr = st.team_abbreviation,
		   r.team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'+ @leagueName + '-whitebg/22/' + st.team_abbreviation + '.png',
		   r.team_page = 'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug 
	  FROM @rankings r
	 INNER JOIN dbo.SMG_Teams st
	    ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug = r.team_slug

	UPDATE @rankings
	   SET record = dbo.SMG_fn_Team_Records(@leagueName, @season_key, team_key, @week_begin)

    -- movers
    DECLARE @rise INT
    DECLARE @fall INT

    SELECT @rise = COUNT(*)
      FROM @rankings
     WHERE ranking_mover = 'RISE'

    IF (@rise > 3)
    BEGIN
        UPDATE @rankings
           SET ranking_mover = ''
         WHERE ranking_mover = 'RISE'
    END
    
    SELECT @fall = COUNT(*)
      FROM @rankings
     WHERE ranking_mover = 'FALL'

    IF (@fall > 3)
    BEGIN
        UPDATE @rankings
           SET ranking_mover = ''
         WHERE ranking_mover = 'FALL'
    END

    -- credits
    DECLARE @credits VARCHAR(MAX)
    DECLARE @expression VARCHAR(100) = '<br />'

	SELECT @credits = credits
      FROM SportsEditDB.dbo.Feeds_Credits
     WHERE [type] = 'rankings-' + @leagueName

    SET @credits = SUBSTRING(@credits, CHARINDEX(@expression, @credits) + LEN(@expression), LEN(@credits))


    SELECT ISNULL(@credits, '') AS credits, @week_begin AS published_on,
	(
		SELECT
		(
			SELECT ranking, ranking_diff, ranking_hilo, record, team_abbr, team_logo, team_page
			  FROM @rankings
			 WHERE ranking_mover = 'RISE'
			 ORDER BY CAST(ranking AS INT) ASC
			   FOR XML RAW('rise'), TYPE
		),
		(
			SELECT ranking, ranking_diff, ranking_hilo, record, team_abbr, team_logo, team_page
			  FROM @rankings
			 WHERE ranking_mover = 'FALL'
			 ORDER BY CAST(ranking AS INT) ASC
			   FOR XML RAW('fall'), TYPE
		)
		FOR XML RAW('movers'), TYPE
	),
	(	
		SELECT ranking, ranking_diff, ranking_hilo, record, team_abbr, team_logo, team_page
		  FROM @rankings
		 ORDER BY ranking
		   FOR XML RAW('rankings'), TYPE
	)
	FOR XML RAW('root'), TYPE


	SET NOCOUNT OFF;
END 

GO
