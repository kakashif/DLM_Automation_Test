USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetFiltersSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetFiltersSolo_XML]
	@leagueName	VARCHAR(100),
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	07/10/2014
-- Description:	get solo filter for jameson
-- Updated:		10/03/2014 - ikenticus: fixing default date logic
-- 				11/18/2014 - ikenticus: fixing Camping World truck series display name (again)
--				01/14/2015 - ikenticus: replacing hardcoded truck replace with corrected table logic
--				01/30/2015 - ikenticus - using league display for Golf instead of hard-coding
--				03/26/2015 - ikenticus - adding motor
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @endpoint VARCHAR(100) = '/Scores.svc/' + @leagueName + '/' 

    DECLARE @dates TABLE (
        league_id VARCHAR(100),
		start_date DATE,
		end_date DATE
    )

	INSERT INTO @dates (league_id, start_date, end_date)
	SELECT l.league_id, CAST(e.start_date_time AS DATE), CAST(e.end_date_time AS DATE)
	  FROM dbo.SMG_Solo_Leagues AS l
	 INNER JOIN dbo.SMG_Solo_Events AS e ON e.league_key = l.league_key AND DATEDIFF(MM, GETDATE(), e.start_date_time) BETWEEN -1 AND 1
	 WHERE l.league_name = @leagueName
	 GROUP BY l.league_id, CAST(e.start_date_time AS DATE), CAST(e.end_date_time AS DATE)

	UPDATE @dates
	   SET end_date = DATEADD(DD, 1, start_date)
	 WHERE end_date IS NULL


    DECLARE @filters TABLE (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        league_id VARCHAR(100),
        [year] INT,
		[month] INT
    )
    
	IF (@leagueName = 'golf')
	BEGIN
		INSERT INTO @filters (league_id)
		VALUES ('pga-tour'), ('champions-tour'), ('european-tour'), ('satellite-tour'), ('lpga-tour')
	END
	ELSE IF (@leagueName = 'motor')
	BEGIN
		INSERT INTO @filters (league_id)
		VALUES ('indycar'), ('formula-one')
	END

	ELSE IF (@leagueName = 'nascar')
	BEGIN
		INSERT INTO @filters (league_id)
		VALUES ('cup-series'), ('semi-pro-series'), ('truck-series')
	END
	ELSE IF (@leagueName = 'tennis')
	BEGIN
		INSERT INTO @filters (league_id)
		VALUES ('mens-tennis'), ('womens-tennis')
	END

	UPDATE f
	   SET f.display = l.league_display
	  FROM @filters AS f
	 INNER JOIN SportsDB.dbo.SMG_Solo_Leagues AS l ON l.league_name = @leagueName AND
		   l.league_id = f.league_id AND season_key = ISNULL(NULLIF(@year, 0), YEAR(GETDATE()))

	DELETE @filters
	 WHERE display IS NULL

	IF (@year = 0 OR @month = 0 OR @year IS NULL OR @month IS NULL)
	BEGIN
		UPDATE f
		   SET f.year = YEAR(d.start_date), f.month = MONTH(d.start_date)
		  FROM @filters AS f
		 INNER JOIN @dates AS d ON d.league_id = f.league_id AND d.start_date <= GETDATE() AND d.end_date > GETDATE()

		-- get future date if emtpy
		UPDATE f
		   SET f.year = YEAR(d.start_date), f.month = MONTH(d.start_date)
		  FROM @filters AS f
		 INNER JOIN @dates AS d ON d.league_id = f.league_id AND d.start_date > GETDATE()
		 WHERE f.year IS NULL OR f.month IS NULL

		-- get past date if still empty
		UPDATE f
		   SET f.year = YEAR(d.start_date), f.month = MONTH(d.start_date)
		  FROM @filters AS f
		 INNER JOIN @dates AS d ON d.league_id = f.league_id AND d.start_date < GETDATE()
		 WHERE f.year IS NULL OR f.month IS NULL
	END
	ELSE
	BEGIN
		UPDATE @filters
		   SET year = @year, month = @month
	END

    
   	SELECT (
               SELECT display, @endpoint + league_id + '/' + CAST([year] AS VARCHAR(4)) + '/' + CAST([month] AS VARCHAR(2)) AS [endpoint]
                 FROM @filters
                ORDER BY id ASC
     			  FOR XML RAW('filters'), TYPE
           )
       FOR XML PATH(''), ROOT('root')

END


GO
