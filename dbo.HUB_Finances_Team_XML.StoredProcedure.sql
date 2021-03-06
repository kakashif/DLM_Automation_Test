USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_Finances_Team_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_Finances_Team_XML]
	@leagueName	VARCHAR(100),
	@teamSlug	VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 03/09/2014
-- Description:	get Salaries using new SMG_Salaries table
--				02/18/2015 - ikenticus: adding editorial overrides
--				03/23/2015 - ikenticus: forgot to add position to ribbon
--				03/26/2015 - ikenticus: excluding status=CUT players
--				04/06/2015 - ikenticus: fixing team payroll display
--              04/07/2015 - John Lin - statistics using regular season
--              04/08/2015 - John Lin - new head shot logic
--              04/21/2015 - John Lin - seperate salaries and finances
--				07/27/2015 - ikenticus - migrating to decoupled player/team keys
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = SportsDB.dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @embargo_season INT

   	-- embargo latest season
   	SELECT @embargo_season = season_key
      FROM SportsDB.dbo.SMG_Default_Dates
   	 WHERE league_key = @leagueName AND page = 'salaries'

    DECLARE @team_logo VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @team_season INT = @embargo_season

    SELECT @team_key = team_key, @team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/220/' + team_abbreviation + '.png'
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @embargo_season AND team_slug = @teamSlug

    -- use earliest team_key for earlier years
    IF (@team_key IS NULL)
	BEGIN
        SELECT TOP 1 @team_key = team_key, @team_season = season_key,
                     @team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/220/' + team_abbreviation + '.png'
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND team_slug = @teamSlug
	     ORDER BY season_key ASC
	END
   
    -- column
	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100)
	)
	INSERT INTO @columns (display, [column])
	VALUES ('Season', 'season'), ('Opening Day', 'opening'), ('Current', 'current'),
	       ('Diff', 'diff'), ('Avg Salary', 'average'), ('Median', 'median')

    IF (@leagueName = 'nhl')
	BEGIN
		DELETE FROM @columns
		 WHERE [column] IN ('opening', 'diff')
	END

    --- row
	DECLARE @salaries TABLE
	(
		season        INT,
		opening_money MONEY,
		current_money MONEY,
		diff_money    MONEY,
		average_money MONEY,
		median_money  MONEY,
        -- display
        opening       VARCHAR(100),
     	[current]     VARCHAR(100),
     	diff          VARCHAR(100),
     	average       VARCHAR(100),
     	median        VARCHAR(100)
	)
	INSERT INTO @salaries (season, opening_money, current_money, diff_money, average_money, median_money)
	SELECT season_key, salary_base, salary, salary_diff, ROUND(salary_average, 0), salary_median
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE team_key = @teamSlug AND season_key <= @embargo_season AND player_key = 'team'

    -- spotlight
    DECLARE @season INT
    DECLARE @payroll VARCHAR(100)
    DECLARE @current VARCHAR(100)
    DECLARE @percent VARCHAR(100)
    DECLARE @average VARCHAR(100)
    DECLARE @median VARCHAR(100)
    -- extra
    DECLARE @current_money MONEY
    DECLARE @past_money MONEY
	DECLARE @gain_loss INT
    
	SELECT TOP 1 @season = season, @current_money = current_money,
	             @current = REPLACE(CONVERT(VARCHAR, current_money, 1), '.00', ''), 
	             @average = REPLACE(CONVERT(VARCHAR, average_money, 1), '.00', ''), @median = REPLACE(CONVERT(VARCHAR, median_money, 1), '.00', '')
	  FROM @salaries
	 ORDER BY season DESC

    SET @payroll = CAST(@season AS VARCHAR) + ' Total Payroll:'
    
    -- percent
	SELECT @past_money = current_money
	  FROM @salaries
	 WHERE season = (@season - 1)

	SET @gain_loss = ROUND(100 * (@current_money - @past_money) / @current_money, 0)
	SET @percent = CASE WHEN @gain_loss > 0 THEN '+' ELSE '-' END + CAST(@gain_loss AS VARCHAR) + '% from ' + CAST(@season - 1 AS VARCHAR) + ' Total Payroll'

    -- display
    UPDATE @salaries
       SET opening = '$ ' + REPLACE(CONVERT(VARCHAR, opening_money, 1), '.00', ''),
       	   [current] = '$ ' + REPLACE(CONVERT(VARCHAR, current_money, 1), '.00', ''), 
       	   diff = (CASE
       	              WHEN diff_money = 0.00 THEN '$ -'
				      ELSE '$ ' + REPLACE(CONVERT(VARCHAR, diff_money, 1), '.00', '')
				  END),
           average = '$ ' + REPLACE(CONVERT(VARCHAR, average_money, 1), '.00', ''),
           median = '$ ' + REPLACE(CONVERT(VARCHAR, median_money, 1), '.00', '')

    -- notes
    DECLARE @notes VARCHAR(MAX)
    
    SELECT @notes = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
     WHERE league_name = @leagueName AND page_id = 'salaries'



	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @notes AS notes,
	(
		SELECT @team_logo AS logo, @payroll AS payroll, @current AS [current], @percent AS [percent], @average AS average, @median AS median
           FOR XML RAW('spotlight'), TYPE
	),
	(
		SELECT 'Top Team Payrolls' AS ribbon,
		(
		    SELECT 'true' AS 'json:Array',
			       season, opening, [current], diff, average, median
			  FROM @salaries
			 ORDER BY season DESC
			   FOR XML RAW('row'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML RAW('table'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

END

GO
