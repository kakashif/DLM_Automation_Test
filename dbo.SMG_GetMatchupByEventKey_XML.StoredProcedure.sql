USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchupByEventKey_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetMatchupByEventKey_XML]
   @leagueKey VARCHAR(30),
   @seasonKey INT,
   @subSeasonType VARCHAR(100),
   @eventKey VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 11/01/2013
  -- Description: get scores by event key
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* DEPRECATED
     
	DECLARE @stats TABLE
	(
	    team_key  VARCHAR(100),
	    [column]  VARCHAR(100),
	    value     VARCHAR(50)
	)
	     
    INSERT INTO @stats (team_key, [column], value)
    SELECT team_key, [column], value
      FROM dbo.SMG_fnGetMatchupStatistics(@eventKey)

			          
    SELECT
	(
        SELECT team_key, [column], value
          FROM @stats
           FOR XML RAW('statistics'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
*/

END

GO
