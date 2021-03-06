USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_Finances_Year_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_Finances_Year_XML]
	@leagueName	VARCHAR(100),
	@year       INT
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

   	IF (@embargo_season IS NULL)
    BEGIN
	    SET @embargo_season = YEAR(GETDATE())
    END

    IF (@year = 0 OR @year > @embargo_season)
    BEGIN   
        SET @year = @embargo_season
    END
    
    -- column
	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100)
	)
	INSERT INTO @columns (display, [column])
	VALUES ('Team', 'team'), ('Opening Day', 'opening'), ('Current', 'current'),
	       ('Diff', 'diff'), ('Avg Salary', 'average'), ('Median', 'median')

    IF (@leagueName = 'nhl')
	BEGIN
		DELETE FROM @columns
		 WHERE [column] IN ('opening', 'diff')
	END

    --- row
	DECLARE @salaries TABLE
	(
		team_key	  VARCHAR(100),
		team          VARCHAR(100),
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
     	median        VARCHAR(100),
		-- extra
		team_slug     VARCHAR(100)
	)
	INSERT INTO @salaries (team_key, opening_money, current_money, diff_money, average_money, median_money)
	SELECT team_key, salary_base, salary, salary_diff, ROUND(salary_average, 0), salary_median
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE league_key = @league_key AND season_key = @year AND player_key = 'team'

    -- team
    DECLARE @team_season INT
    
    SELECT TOP 1 @team_season = season_key
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key >= @year
	 ORDER BY season_key ASC

	UPDATE s
	   SET s.team = st.team_last, s.team_key = st.team_key
	  FROM @salaries AS s
	 INNER JOIN dbo.SMG_Teams AS st
		ON st.season_key = @team_season AND st.team_slug = s.team_key

    -- spotlight
    DECLARE @team_logo VARCHAR(100)
    DECLARE @payroll VARCHAR(100) = CAST(@year AS VARCHAR) + ' Total Payroll:'   
    DECLARE @current VARCHAR(100)
    DECLARE @percent VARCHAR(100)
    DECLARE @average VARCHAR(100)
    DECLARE @median VARCHAR(100)
    -- extra
    DECLARE @team_key VARCHAR(100)
    DECLARE @current_money MONEY
    DECLARE @past_money MONEY
	DECLARE @gain_loss INT
    
	SELECT TOP 1 @team_key = team_key, @current_money = current_money,
	             @current = REPLACE(CONVERT(VARCHAR, current_money, 1), '.00', ''), 
	             @average = REPLACE(CONVERT(VARCHAR, average_money, 1), '.00', ''), @median = REPLACE(CONVERT(VARCHAR, median_money, 1), '.00', '')
	  FROM @salaries
	 ORDER BY current_money DESC

    -- percent
	SELECT @past_money = salary
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE season_key = (@year - 1) AND team_key = @team_key AND player_key = 'team'

	SET @gain_loss = ROUND(100 * (@current_money - @past_money) / @current_money, 0)
	SET @percent = CASE WHEN @gain_loss > 0 THEN '+' ELSE '-' END + CAST(@gain_loss AS VARCHAR) + '% from ' + CAST(@year - 1 AS VARCHAR) + ' Total Payroll'

    SELECT @team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/220/' + team_abbreviation + '.png'
      FROM dbo.SMG_Teams
     WHERE season_key = @team_season AND team_key = @team_key

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
			       team_key, team, opening, [current], diff, average, median, team_slug
			  FROM @salaries
			 ORDER BY current_money DESC, team ASC
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
