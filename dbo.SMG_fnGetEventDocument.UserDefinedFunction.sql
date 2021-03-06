USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetEventDocument]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[SMG_fnGetEventDocument] (
    @eventKey VARCHAR(100)
)
RETURNS @documents TABLE (
    xml_blob  XML
)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/11/2013
-- Description:	get event document
-- =============================================
BEGIN
/* DEPRECATED
    
    INSERT INTO @documents (xml_blob)
	SELECT TOP 1 dc.sportsml_blob
	  FROM dbo.document_contents dc WITH (NOLOCK)
	 INNER JOIN dbo.document_fixtures_events dfe WITH (NOLOCK)
	    ON dfe.latest_document_id = dc.document_id
	 INNER JOIN dbo.Events_Warehouse ew WITH (NOLOCK)
	    ON ew.event_id = dfe.event_id
	 INNER JOIN dbo.document_fixtures df WITH (NOLOCK)
	    ON df.id = dfe.document_fixture_id AND df.fixture_key IN ('event-stats-composite', 'event-stats', 'event-stats-progressive')
	 WHERE ew.event_key = @eventKey
	 ORDER BY dc.document_id DESC
*/           
    RETURN
END

GO
