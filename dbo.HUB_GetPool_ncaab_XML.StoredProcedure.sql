USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetPool_ncaab_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetPool_ncaab_XML]
    @year INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/10/2015
-- Description:	get bracket teams
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @pool_key VARCHAR(100)

    SELECT @pool_key = pool_key
      FROM dbo.UGC_Pool_Names
     WHERE league_name = 'ncaab' AND season_key = (@year - 1) AND [guid] = 'SMG-ADMIN'
                    
    EXEC dbo.HUB_GetPool_XML @pool_key
	    
    SET NOCOUNT OFF;
END




GO
