USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByDate_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresFilterByDate_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get scores filter by date for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresFilterByDateFilter_XML @leagueName, @year, @month, @day
   
END

GO
