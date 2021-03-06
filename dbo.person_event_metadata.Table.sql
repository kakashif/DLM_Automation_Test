USE [SportsDB]
GO
/****** Object:  Table [dbo].[person_event_metadata]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[person_event_metadata](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[person_id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[status] [varchar](100) NULL,
	[health] [varchar](100) NULL,
	[weight] [varchar](100) NULL,
	[role_id] [int] NULL,
	[position_id] [int] NULL,
	[team_id] [int] NULL,
	[lineup_slot] [int] NULL,
	[lineup_slot_sequence] [int] NULL,
 CONSTRAINT [PK__person_event_met__22751F6C] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
