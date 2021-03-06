USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewCurrentOrLastSeasonByLeague]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[ViewCurrentOrLastSeasonByLeague]
AS
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Get most recent season (current or last) for all leagues
-- =============================================

	SELECT	
			la.id AS league_id,
			la.affiliation_key AS league_key, 
			ss.sub_season_type AS sub_season_type,
			ss.sub_season_key,
			s.season_key AS season_key,
			s.id AS season_id,
			ss.id AS sub_season_id,
			ss.start_date_time AS start_date_time,
			ss.end_date_time AS end_date_time
			
	FROM		
		dbo.affiliations AS la  WITH (NOLOCK) 
	INNER JOIN	dbo.seasons AS s WITH (NOLOCK) 
		ON	la.id = s.league_id
		AND	s.publisher_id = la.publisher_id	
	INNER JOIN	dbo.sub_seasons AS ss WITH (NOLOCK) 
		ON s.id= ss.season_id
		
	WHERE		
		la.publisher_id = 2 
	AND	la.affiliation_type = 'league' 
	AND	ss.start_date_time IS NOT NULL 
	AND	ss.end_date_time IS NOT NULL 
	AND ss.start_date_time <= GETDATE()
	AND NOT EXISTS (SELECT 1 FROM dbo.sub_seasons AS sub_s 
						INNER JOIN dbo.seasons AS sn
							ON sn.id = sub_s.season_id
						WHERE 
								sn.league_id = la.id
							AND sub_s.id != ss.id 
							AND sub_s.start_date_time > ss.start_date_time 
							AND (sub_s.start_date_time <= GETDATE() OR sub_s.end_date_time < GETDATE())
							AND sub_s.sub_season_type = ss.sub_season_type)
	--AND ss.sub_season_type = 'season-regular'
	




GO
