USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_MLB_Defense]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_MLB_Defense]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Defense Team Leader statistics for MLB
-- =============================================
AS
 	SELECT  
 			teams.team_key,
			dn.first_name,
			dn.last_name,
			persons.person_key,
			persons.id AS person_id,
			e.event_key,
			e.id AS event_id,
			e.start_date_time,
			bds.putouts
	FROM
	dbo.[events] AS e  WITH (NOLOCK) 
	INNER JOIN dbo.affiliations_events AS ae  WITH (NOLOCK) 
		ON ae.event_id = e.id
	INNER JOIN dbo.affiliations AS a  WITH (NOLOCK) 
		ON a.id = ae.affiliation_id
		AND a.affiliation_key = 'l.mlb.com'
		AND a.affiliation_type = 'league'
	INNER JOIN dbo.events_sub_seasons AS ess  WITH (NOLOCK) 
		ON ess.event_id = e.id
	INNER JOIN dbo.sub_seasons AS ss  WITH (NOLOCK) 
		ON ss.id = ess.sub_season_id
		AND ss.sub_season_type = 'season-regular'
	INNER JOIN dbo.stats AS defensive_stats  WITH (NOLOCK) 
		ON  defensive_stats.stat_coverage_id = e.id
		AND defensive_stats.stat_repository_type = 'baseball_defensive_stats'
		AND defensive_stats.stat_holder_type = 'persons'
		AND defensive_stats.stat_coverage_type = 'events'
		AND defensive_stats.context = 'event'
		--AND defensive_stats.scope = 'position:all'
	INNER JOIN dbo.baseball_defensive_stats  AS bds  WITH (NOLOCK) 
		ON bds.id = defensive_stats.stat_repository_id
	INNER JOIN dbo.person_event_metadata AS pem  WITH (NOLOCK) 
		ON pem.event_id = e.id
	INNER JOIN dbo.teams  WITH (NOLOCK) 
		ON pem.team_id = teams.id
	INNER JOIN dbo.persons  WITH (NOLOCK) 
		ON pem.person_id =  persons.id
		AND defensive_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn   WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com');

GO
