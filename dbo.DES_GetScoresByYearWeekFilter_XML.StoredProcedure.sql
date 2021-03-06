USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresByYearWeekFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresByYearWeekFilter_XML]
   @year    INT,
   @week    VARCHAR(100),
   @filter	VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get scores for NCAAF for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScores_XML 'ncaaf', @year, NULL, @week, NULL, @filter

END

GO
