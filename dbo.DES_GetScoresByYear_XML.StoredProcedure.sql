USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresByYear_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[DES_GetScoresByYear_XML]
   @year INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get scores for NCAAF for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresByYearWeekFilter_XML @year, 'bowls', NULL

END

GO
