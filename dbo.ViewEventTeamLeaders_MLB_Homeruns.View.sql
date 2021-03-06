USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_MLB_Homeruns]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_MLB_Homeruns]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets enumerated Home Runs
-- =============================================
AS
	SELECT 
		t.team_key AS team_key, 
		dn.first_name AS first_name, 
		dn.last_name AS last_name, 
		p.person_key AS person_key, 
		e.event_key AS event_key,
		e.id AS event_id,
		e.start_date_time AS start_date_time,
		bap.play_type AS play_type,
		bas.sequence_number AS sequence_number,
		rbi,
		runs_scored,
		earned_runs_scored

	FROM 
		dbo.baseball_event_states AS bas  WITH (NOLOCK) 
	INNER JOIN dbo.baseball_action_plays AS bap  WITH (NOLOCK) 
		ON bas.id = bap.baseball_event_state_id
		AND bap.play_type = 'home-run'
	INNER JOIN dbo.events AS e  WITH (NOLOCK) 
		ON bas.event_id = e.id
		AND e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com')
	INNER JOIN participants_events AS pe  WITH (NOLOCK) 
		ON pe.event_id = e.id
		AND pe.participant_type = 'teams'
	INNER JOIN dbo.persons AS p  WITH (NOLOCK) 
		ON bas.batter_id = p.id
	INNER JOIN person_phases AS pp WITH (NOLOCK) 
		ON pp.person_id = p.id
		AND pp.membership_id = pe.participant_id 
		AND pp.membership_type = 'teams'
	INNER JOIN dbo.display_names AS dn  WITH (NOLOCK) 
		ON bas.batter_id = dn.entity_id
		AND  dn.entity_type = 'persons'
	INNER JOIN dbo.teams AS t WITH (NOLOCK) 
		ON t.id = pe.participant_id 
	INNER JOIN dbo.display_names AS dt  WITH (NOLOCK) 
		ON dt.entity_id = t.id 
		AND dt.entity_type = 'teams';


GO
