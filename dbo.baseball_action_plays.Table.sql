USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_action_plays]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[baseball_action_plays](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[baseball_event_state_id] [int] NOT NULL,
	[play_type] [varchar](100) NULL,
	[out_type] [varchar](100) NULL,
	[notation] [varchar](100) NULL,
	[notation_yaml] [text] NULL,
	[baseball_defensive_group_id] [int] NULL,
	[comment] [varchar](512) NULL,
	[runner_on_first_advance] [varchar](40) NULL,
	[runner_on_second_advance] [varchar](40) NULL,
	[runner_on_third_advance] [varchar](40) NULL,
	[outs_recorded] [int] NULL,
	[rbi] [int] NULL,
	[runs_scored] [int] NULL,
	[earned_runs_scored] [varchar](100) NULL,
 CONSTRAINT [PK__baseball_action___36B12243] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
