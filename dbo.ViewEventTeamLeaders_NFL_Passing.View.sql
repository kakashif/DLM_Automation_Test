USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NFL_Passing]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NFL_Passing]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Passing Team Leader statistics for NFL
-- =============================================
AS
 	SELECT  teams.team_key,
			dn.first_name,
			dn.last_name,
			persons.person_key,
			persons.id AS person_id,
			e.event_key,
			e.id AS event_id,
			e.start_date_time,
			afps.passes_interceptions,
			afps.passes_yards_gross,
			afps.passes_touchdowns,
			afps.passes_completions,
			afps.passes_attempts, 
			afps.receptions_total,
			afps.receptions_yards,
			afps.receptions_touchdowns
	FROM
	dbo.[events] AS e WITH (NOLOCK)
	INNER JOIN dbo.affiliations_events AS ae WITH (NOLOCK)
		ON ae.event_id = e.id
	INNER JOIN dbo.affiliations AS a WITH (NOLOCK)
		ON a.id = ae.affiliation_id
		AND a.affiliation_key = 'l.nfl.com'
		AND a.affiliation_type = 'league'
	INNER JOIN dbo.events_sub_seasons as ess WITH (NOLOCK)
		ON ess.event_id = e.id
	INNER JOIN dbo.sub_seasons as ss WITH (NOLOCK)
		ON ss.id = ess.sub_season_id
		AND ss.sub_season_type = 'season-regular'
	INNER JOIN dbo.stats AS passing_stats WITH (NOLOCK)
		ON  passing_stats.stat_coverage_id = e.id
		AND passing_stats.stat_repository_type = 'american_football_passing_stats'
		AND passing_stats.stat_holder_type = 'persons'
		AND passing_stats.stat_coverage_type = 'events'
		AND passing_stats.context = 'event'
	INNER JOIN dbo.american_football_passing_stats AS afps WITH (NOLOCK)
		ON afps.id = passing_stats.stat_repository_id
		AND  afps.passes_attempts IS NOT NULL
	INNER JOIN dbo.person_event_metadata as pem WITH (NOLOCK)
		ON pem.event_id = e.id
	INNER JOIN dbo.teams WITH (NOLOCK)
		on pem.team_id = teams.id
	INNER JOIN dbo.persons WITH (NOLOCK) 
		ON pem.person_id =  persons.id
		AND passing_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers WHERE publisher_key = 'sportsnetwork.com');


GO
