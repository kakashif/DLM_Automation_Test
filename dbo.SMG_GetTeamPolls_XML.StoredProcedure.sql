USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamPolls_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamPolls_XML]
	@leagueName	VARCHAR(100),
	@teamSlug   VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 10/02/2013
-- Description:	get team polls
-- Update:      10/21/2013 - John Lin - use team slug
--              10/29/2013 - ikenticus: fixing team polls order, adding class, eliminating Harris
--				10/31/2013 - ikenticus: forgot to remove the ORDER BY in the XML since it was ordered previously
--				11/15/2013 - ikenticus: extending range of latest poll to 3 days back to cover discrepancy between AP and BCS
--              06/17/2014 - John Lin - use league name for SMG_Default_Dates
--              09/16/2014 - cmchiu - add Amway prefix for Coaches Poll label
--				01/13/2015 - ikenticus - remove hard-coded Amway label and use existing sponsor
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_first VARCHAR(100)
	DECLARE @team_last VARCHAR(100)
	DECLARE @team_abbr VARCHAR(100)
	
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'statistics'
    
	SELECT @team_key = team_key, @team_first = team_first, @team_last = team_last, @team_abbr = team_abbreviation
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug


	DECLARE @poll_date DATE;
	
	SELECT TOP 1 @poll_date = poll_date
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName
	 ORDER BY poll_date DESC


	DECLARE @polls TABLE
	(
		poll_name	 VARCHAR(100),
		poll_date	 DATE,
		ranking		 INT,
	    poll_type_id INT
	)
	

	-- Dictate the poll order
	DECLARE @poll_order TABLE (
		poll_name	VARCHAR(100),
		[order]		INT
	)
	INSERT INTO @poll_order (poll_name, [order])
	VALUES ('Coaches Poll', 1), ('AP', 2), ('BCS', 3)


	;WITH team_polls AS (
		SELECT poll_name, poll_date, ranking, poll_type_id, RANK() OVER(PARTITION BY poll_name ORDER BY poll_date DESC) AS latest
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND team_key = @team_abbr AND poll_date BETWEEN DATEADD(DAY, -3, @poll_date) AND DATEADD(DAY, 1, @poll_date)
		 GROUP BY poll_name, poll_date, ranking, poll_type_id
	) INSERT INTO @polls
	SELECT t.poll_name, poll_date, ranking, poll_type_id
	FROM team_polls AS t
	INNER JOIN @poll_order AS o ON o.poll_name = t.poll_name
	WHERE latest = 1
	ORDER BY o.[order]

	-- Check for sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@leagueName)
	AND page_id = 'smg-usat'
	AND name = 'sponsor'

	IF (@sponsor IS NOT NULL)
	BEGIN
		UPDATE @polls
		   SET poll_name = @sponsor + ' ' + poll_name
		 WHERE poll_name = 'Coaches Poll'
	END

	SELECT @team_first AS team_first, @team_last AS team_last, @team_abbr AS team_class_name,
	(
		SELECT ranking, poll_name
		  FROM @polls
		   FOR XML RAW('polls'), TYPE
	)
	FOR XML RAW('root'), TYPE 

	SET NOCOUNT OFF;
END 

GO
