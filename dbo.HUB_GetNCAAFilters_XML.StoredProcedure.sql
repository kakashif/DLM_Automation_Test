USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAFilters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAFilters_XML]
    @sport VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/30/2014
  -- Description: get filter for ncaa conference
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.HUB_GetNCAAFiltersByWeek_XML @sport, NULL

END

GO
