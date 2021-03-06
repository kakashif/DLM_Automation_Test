USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_MLB_Pitching]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_MLB_Pitching]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Pitching Team Leader statistics for MLB
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
			bps.era,
			bps.saves
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
	INNER JOIN dbo.stats AS pitching_stats  WITH (NOLOCK) 
		ON  pitching_stats.stat_coverage_id = e.id
		AND pitching_stats.stat_repository_type = 'baseball_pitching_stats'
		AND pitching_stats.stat_holder_type = 'persons'
		AND pitching_stats.stat_coverage_type = 'events'
		AND pitching_stats.context = 'event'
	INNER JOIN dbo.baseball_pitching_stats AS bps  WITH (NOLOCK) 
		ON bps.id = pitching_stats.stat_repository_id
		AND bps.event_credit IS NOT NULL
		AND  bps.era IS NOT NULL
	INNER JOIN dbo.person_event_metadata AS pem  WITH (NOLOCK) 
		ON pem.event_id = e.id
	INNER JOIN dbo.teams  WITH (NOLOCK) 
		ON pem.team_id = teams.id
	INNER JOIN dbo.persons   WITH (NOLOCK) 
		ON pem.person_id = persons.id
		AND pitching_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn  WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com');


GO
