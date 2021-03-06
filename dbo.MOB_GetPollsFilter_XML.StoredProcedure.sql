USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetPollsFilter_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetPollsFilter_XML]
    @leagueName VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/09/2014
  -- Description: get polls type and week
  -- Update: 01/17/2014 - John Lin - populate type via group by
  --         02/26/2014 - John Lin - Coaches Poll rename to Amway Coaches Poll for ncaaf
  --		 03/20/2014 - ikenticus - using sponsor instead of hard-coded Amway
  --		 10/10/2014 - ikenticus - SOC-114, commenting out Harris Poll
  --		 07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	DECLARE @poll_year TABLE (
		[type]       VARCHAR(100),
		type_display VARCHAR(100),
		[order]      INT,
		season_key   INT
	)
	
	INSERT INTO @poll_year ([type])
	SELECT fixture_key
	  FROM SportsEditDB.dbo.SMG_Polls
	 GROUP BY fixture_key

	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE LOWER(league_name) = LOWER(@leagueName)
	   AND page_id = 'smg-usat' AND name = 'sponsor'

	IF (@sponsor IS NOT NULL)
	BEGIN
    	UPDATE @poll_year
	       SET type_display = @sponsor + ' Coaches Poll', [order] = 1
	     WHERE [type] = 'smg-usat'
	END
	ELSE
	BEGIN
    	UPDATE @poll_year
	       SET type_display = 'Coaches Poll', [order] = 1
	     WHERE [type] = 'smg-usat'
    END

	UPDATE @poll_year
	   SET type_display = 'AP Poll', [order] = 2
	 WHERE [type] = 'poll-ap'

	UPDATE @poll_year
	   SET type_display = 'BCS Poll', [order] = 3
	 WHERE [type] = 'ranking-bcs'

	/*
	UPDATE @poll_year
	   SET type_display = 'Harris Poll', [order] = 4
	 WHERE [type] = 'poll-harris'
	*/

    UPDATE @poll_year
       SET season_key = (SELECT TOP 1 season_key
                            FROM SportsEditDB.dbo.SMG_Polls
                           WHERE league_key = @leagueName AND fixture_key = [type]
                           ORDER BY poll_date DESC)


	DECLARE @poll_year_week TABLE (
		[type]       VARCHAR(100),
		type_display VARCHAR(100),
		[order]      INT,
		season_key   INT,
		[week]       INT,
		week_display VARCHAR(100)
	)
	
	INSERT INTO @poll_year_week ([type], type_display, [order], season_key, [week])
	SELECT py.[type], py.type_display, py.[order], py.season_key, sp.[week]
	  FROM @poll_year py
	 INNER JOIN SportsEditDB.dbo.SMG_Polls sp
	    ON sp.league_key = @leagueName AND sp.season_key = py.season_key AND sp.fixture_key = py.[type] AND sp.ranking = 1 AND
	       (sp.publish_date_time IS NULL OR sp.publish_date_time < GETDATE())
	
	UPDATE @poll_year_week
	   SET week_display = 'Week ' + CAST([week] AS VARCHAR)

    DECLARE @id INT = 1
    DECLARE @max INT
    DECLARE @max_week INT
    DECLARE @type VARCHAR(100)    

    SELECT TOP 1 @max = [order]
      FROM @poll_year
     ORDER BY [order] DESC
        
    WHILE (@id <= @max)
    BEGIN
        SELECT @type = [type]
          FROM @poll_year
         WHERE [order] = @id

        SELECT TOP 1 @max_week = [week]
          FROM @poll_year_week         
         WHERE [type] = @type
         ORDER BY [week] DESC             

        UPDATE @poll_year_week
           SET week_display = 'Preseason'
         WHERE [type] = @type AND [week] = 1
         
        IF (@leagueName = 'ncaaf')
        BEGIN        
            UPDATE @poll_year_week
               SET week_display = 'Final Ranking'
             WHERE [type] = @type AND [week] >= 16 AND [week] = @max_week
        END
        ELSE
        BEGIN
            UPDATE @poll_year_week
               SET week_display = 'Postseason'
             WHERE [type] = @type AND [week] = 20

            UPDATE @poll_year_week
               SET week_display = 'Postseason (Final)'
             WHERE [type] = @type AND [week] >= 21 AND [week] = @max_week
        END

        SET @id = @id + 1
    END

    SELECT
    (
        SELECT p.[type] AS id, p.type_display AS display,
               (
                   SELECT w.[type] + '/' + CAST(w.season_key AS VARCHAR) + '/' + CAST(w.[week] AS VARCHAR) AS id, w.week_display AS display 
                     FROM @poll_year_week w
                    WHERE w.[type] = p.[type]
                    ORDER BY w.[week] ASC
                      FOR XML RAW('weeks'), TYPE
               )
		  FROM @poll_year_week p
		 GROUP BY p.[type], p.type_display, p.[order]
		 ORDER BY p.[order] ASC
		FOR XML RAW('polls'), TYPE
    )
    FOR XML RAW('root'), TYPE

    SET NOCOUNT OFF
END

GO
