USE [SportsDB]
GO
/****** Object:  Table [dbo].[soccer_action_plays]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[soccer_action_plays](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[soccer_event_state_id] [int] NOT NULL,
	[play_type] [varchar](100) NULL,
	[score_attempt_type] [varchar](100) NULL,
	[play_result] [varchar](100) NULL,
	[comment] [varchar](100) NULL,
 CONSTRAINT [PK__soccer_action_pl__2DE6D218] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
