USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByYear_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresFilterByYear_XML]
   @year INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get scores filter for NCAAF for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresFilterByYearWeekFilter_XML @year, 'bowls', 'div1.a'

END

GO
