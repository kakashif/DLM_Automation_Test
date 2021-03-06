USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamBGPosition_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamBGPosition_XML]
   @leagueKey VARCHAR(100),
   @seasonKey INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/26/2013
  -- Description: get team background rgb and x y position
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
        SELECT
        (
            SELECT team_key,
                   team_abbreviation AS abbr,
                   'rgb(' + rgb + ')' AS [background-color],
                   (CASE
                       WHEN y_coordinate = 1 AND x_coordinate = 1 THEN '0px 0px'
                       WHEN y_coordinate = 1 THEN '0px -' + CAST((x_coordinate - 1) * 30 AS VARCHAR(100)) + 'px'
                       WHEN x_coordinate = 1 THEN '-' + CAST((y_coordinate - 1) * 30 AS VARCHAR(100)) + 'px 0px'
                       ELSE '-' + CAST((y_coordinate - 1) * 30 AS VARCHAR(100)) + 'px -' + CAST((x_coordinate - 1) * 30 AS VARCHAR(100)) + 'px'                   
                   END) AS [background-position]
              FROM dbo.SMG_Teams
             WHERE league_key = @leagueKey AND season_key = @seasonKey
               FOR XML RAW('team'), TYPE
        )
        FOR XML RAW('root'), TYPE

END

GO
