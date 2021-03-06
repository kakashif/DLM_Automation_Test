USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventMore_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventMore_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/04/2014
-- Description:	get more event for desktop
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    EXEC dbo.DES_GetEventMoreFilter_XML @leagueName, @seasonKey, @eventId, NULL
         	    
    SET NOCOUNT OFF;
END

GO
