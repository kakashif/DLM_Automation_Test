USE [SportsDB]
GO
/****** Object:  Table [dbo].[soccer_action_fouls]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[soccer_action_fouls](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[soccer_event_state_id] [int] NOT NULL,
	[foul_name] [varchar](100) NULL,
	[foul_result] [varchar](100) NULL,
	[foul_type] [varchar](100) NULL,
	[fouler_id] [varchar](100) NULL,
	[recipient_type] [varchar](100) NULL,
	[recipient_id] [int] NOT NULL,
	[comment] [varchar](512) NULL,
 CONSTRAINT [PK__soccer_action_fo__2BFE89A6] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
