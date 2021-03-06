USE [SportsDB]
GO
/****** Object:  View [dbo].[IV_Participants_Events]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[IV_Participants_Events]
WITH SCHEMABINDING

AS
/*********************************************************************
 * Name:     dbo.[IV_Participants_Events]
 * Author:   Shabeer Syed
 * Date:     10/19/2011
 *
 * Purpose/Description:
 *		 
 *
 * Table and Alias Definitions:
 *     PARTICIPANTS_EVENTS    
 *     T_
 *     T_ 
 *  
 * Called Programs:
 *     NONE
 * 
 *********************************************************************
 * Date - Changed By
 * Change Description
 *  
 *********************************************************************/	
	select  
			 id
			,participant_type
			,participant_id
			,event_id
			,alignment
			,score
			,event_outcome
			,result_effect
			,score_attempts
			,sort_order
			,score_type
	from	dbo.participants_events 
	where	(alignment =  'home' or  alignment = 'away')
	and		participant_type = 'teams' 
	




GO
