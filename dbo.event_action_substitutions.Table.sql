USE [SportsDB]
GO
/****** Object:  Table [dbo].[event_action_substitutions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[event_action_substitutions](
	[id] [int] NOT NULL,
	[event_state_id] [int] NOT NULL,
	[person_original_id] [int] NOT NULL,
	[person_original_position_id] [int] NOT NULL,
	[person_replacing_id] [int] NOT NULL,
	[person_replacing_position_id] [int] NOT NULL,
	[substitution_reason] [varchar](100) NULL,
	[comment] [varchar](512) NULL,
 CONSTRAINT [PK_event_action_substitutions] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
