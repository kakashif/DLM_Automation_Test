USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetScoresByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[NAT_GetScoresByYearSubSeasonTypeWeek_XML]
   @host VARCHAR(100),
   @year INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/08/2014
  -- Description: get scores for NFL for native
  -- Update: 08/05/2014 - Johh Lin - add domain
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.NAT_GetScores_XML @host, 'nfl', @year, @subSeasonType, @week, NULL, NULL
        
END

GO
